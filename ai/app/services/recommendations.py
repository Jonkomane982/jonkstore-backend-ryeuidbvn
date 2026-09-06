import pandas as pd
from typing import List, Dict, Any
from uuid import UUID
from datetime import datetime
from app.db.data_service import DataService
from app.models.schemas import ModelRun, Recommendation
from sqlalchemy.orm import Session

class RecommendationService:
    def __init__(self, db: Session, data_service: DataService):
        self.db = db
        self.data_service = data_service
        self.model_name = "jonkai_recommender_v1"
        self.model_version = "1.0.0"

    def generate_inventory_recommendations(self, business_id: UUID) -> List[Dict[str, Any]]:
        """
        Generates RESTOCK recommendations based on inventory levels and sales velocity.
        """
        # 1. Fetch data
        inventory_df = self.data_service.get_inventory_status(business_id)
        velocity_df = self.data_service.get_product_sales_velocity(business_id, days=30)

        if inventory_df.empty:
            return []

        # 2. Merge and calculate coverage
        df = inventory_df.merge(velocity_df, on='product_id', how='left').fillna(0)

        # Calculate stock coverage in days
        # If velocity is 0, coverage is infinite (set to a high number)
        df['coverage_days'] = df.apply(
            lambda x: x['quantity'] / x['avg_daily_velocity'] if x['avg_daily_velocity'] > 0 else 365,
            axis=1
        )

        # 3. Identify products with low coverage (e.g., less than 7 days)
        low_stock_items = df[df['coverage_days'] < 7].copy()

        if low_stock_items.empty:
            return []

        # 4. Record Run
        model_run = ModelRun(
            model_name=self.model_name,
            model_version=self.model_version,
            input_feature_set="inventory_levels_sales_velocity",
            performance_metrics={"threshold_days": 7}
        )
        self.db.add(model_run)
        self.db.flush()

        results = []
        for _, row in low_stock_items.iterrows():
            rec_title = f"Restock {row['name']}"
            reasoning = (f"Current stock ({row['quantity']}) is expected to last only "
                         f"{row['coverage_days']:.1f} days based on recent sales velocity.")

            # Persist Recommendation
            rec = Recommendation(
                business_id=business_id,
                type="RESTOCK",
                priority="HIGH" if row['coverage_days'] < 3 else "MEDIUM",
                title=rec_title,
                reasoning=reasoning,
                status="ACTIVE"
            )
            self.db.add(rec)

            results.append({
                "product_id": str(row['product_id']),
                "product_name": row['name'],
                "coverage_days": float(row['coverage_days']),
                "priority": rec.priority,
                "reasoning": reasoning
            })

        self.db.commit()
        return results
