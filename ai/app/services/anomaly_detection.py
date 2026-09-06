import pandas as pd
import numpy as np
from typing import List, Dict, Any
from uuid import UUID
from datetime import datetime
from app.db.data_service import DataService
from app.models.schemas import ModelRun, Prediction # Reuse schemas or add Anomaly schema
from sqlalchemy.orm import Session
# Note: In a full implementation, we'd have a specific Anomaly table in schemas.py
from app.models.schemas import Base
from sqlalchemy import Column, Text, JSON, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

class Anomaly(Base):
    __tablename__ = "anomalies"
    __table_args__ = {"schema": "jonkai_ai"}

    id = Column(PG_UUID(as_uuid=True), primary_key=True)
    business_id = Column(PG_UUID(as_uuid=True), nullable=False)
    run_id = Column(PG_UUID(as_uuid=True), nullable=False)
    target_entity_type = Column(Text, nullable=False)
    target_entity_id = Column(PG_UUID(as_uuid=True), nullable=False)
    anomaly_type = Column(Text, nullable=False)
    severity = Column(Text, nullable=False) # LOW, MEDIUM, HIGH, CRITICAL
    evidence = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True))

class AnomalyDetectionService:
    def __init__(self, db: Session, data_service: DataService):
        self.db = db
        self.data_service = data_service
        self.model_name = "jonkai_anomaly_detector_v1"
        self.model_version = "1.0.0"

    def detect_sales_anomalies(self, business_id: UUID) -> List[Dict[str, Any]]:
        """
        Detects unusual sales volume/revenue patterns using Z-score.
        """
        df = self.data_service.get_sales_timeseries(business_id)
        if df.empty or len(df) < 14:
            return []

        # Calculate Z-score for revenue
        mean = df['revenue'].mean()
        std = df['revenue'].std()

        if std == 0:
            return []

        df['z_score'] = (df['revenue'] - mean) / std

        # High threshold for anomalies
        anomalies = df[np.abs(df['z_score']) > 2.5].copy()

        if anomalies.empty:
            return []

        # Record Run
        model_run = ModelRun(
            model_name=self.model_name,
            model_version=self.model_version,
            input_feature_set="historical_revenue",
            performance_metrics={"threshold": 2.5}
        )
        self.db.add(model_run)
        self.db.flush()

        results = []
        for _, row in anomalies.iterrows():
            severity = "HIGH" if abs(row['z_score']) > 3.5 else "MEDIUM"

            # This would normally use a proper Anomaly model from schemas.py
            # For this MVP, we log the result
            results.append({
                "date": row['date'].strftime("%Y-%m-%d"),
                "revenue": float(row['revenue']),
                "z_score": float(row['z_score']),
                "severity": severity,
                "evidence": f"Revenue of {row['revenue']} is {row['z_score']:.2f} standard deviations from the mean."
            })

            # In a real app:
            # anomaly_record = Anomaly(...)
            # self.db.add(anomaly_record)

        self.db.commit()
        return results
