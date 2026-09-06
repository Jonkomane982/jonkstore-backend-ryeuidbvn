import pandas as pd
import numpy as np
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from sklearn.metrics import mean_absolute_error, root_mean_squared_error
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from uuid import UUID
from app.db.data_service import DataService
from app.models.schemas import ModelRun, Prediction
from sqlalchemy.orm import Session

class ForecastingService:
    def __init__(self, db: Session, data_service: DataService):
        self.db = db
        self.data_service = data_service
        self.model_name = "jonkai_sales_forecast_v1"
        self.model_version = "1.0.0"

    def forecast_sales(self, business_id: UUID, branch_id: Optional[UUID] = None, horizon_days: int = 7) -> Dict[str, Any]:
        """
        Generates a sales forecast using historical data.
        """
        # 1. Fetch data
        df = self.data_service.get_sales_timeseries(business_id, branch_id)

        if df.empty or len(df) < 5:
            return {
                "status": "INSUFFICIENT_DATA",
                "reason": f"Required at least 5 days of history, found {len(df)}."
            }

        # Ensure we have a continuous date range
        df = df.set_index('date').asfreq('D').fillna(0)

        # 2. Train/Test Split (Chronological)
        train_size = int(len(df) * 0.8)
        train, test = df.iloc[:train_size], df.iloc[train_size:]

        # 3. Model: Exponential Smoothing (Holt-Winters)
        # We use simple exponential smoothing if history is short
        try:
            model = ExponentialSmoothing(train['revenue'], seasonal_periods=None, trend='add', seasonal=None)
            model_fit = model.fit()

            # 4. Validation
            predictions = model_fit.forecast(len(test))
            mae = mean_absolute_error(test['revenue'], predictions)
            rmse = root_mean_squared_error(test['revenue'], predictions)

            # 5. Record Model Run
            model_run = ModelRun(
                model_name=self.model_name,
                model_version=self.model_version,
                input_feature_set="historical_revenue_volume",
                performance_metrics={"mae": mae, "rmse": rmse}
            )
            self.db.add(model_run)
            self.db.flush() # Get ID

            # 6. Generate Forecast
            full_model = ExponentialSmoothing(df['revenue'], seasonal_periods=None, trend='add', seasonal=None)
            full_fit = full_model.fit()
            forecast = full_fit.forecast(horizon_days)

            # 7. Persist Predictions
            forecast_results = []
            for i, val in enumerate(forecast):
                target_date = df.index[-1] + timedelta(days=i+1)
                pred = Prediction(
                    business_id=business_id,
                    run_id=model_run.id,
                    target_entity_type="BUSINESS" if not branch_id else "BRANCH",
                    target_entity_id=business_id if not branch_id else branch_id,
                    prediction_type="REVENUE",
                    forecast_start=target_date,
                    forecast_end=target_date,
                    predicted_value=float(max(0, val)),
                    confidence_score=None # Statistical confidence interval could go here
                )
                self.db.add(pred)
                forecast_results.append({
                    "date": target_date.strftime("%Y-%m-%d"),
                    "predicted_revenue": float(max(0, val))
                })

            self.db.commit()

            return {
                "status": "SUCCESS",
                "model_run_id": str(model_run.id),
                "forecast": forecast_results,
                "metrics": {"mae": mae, "rmse": rmse}
            }

        except Exception as e:
            self.db.rollback()
            return {
                "status": "ERROR",
                "reason": str(e)
            }
