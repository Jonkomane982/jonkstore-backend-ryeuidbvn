import pandas as pd
from uuid import UUID
from typing import Dict, Any, Optional
from app.db.data_service import DataService
from sqlalchemy.orm import Session

class AnalyticsService:
    def __init__(self, db: Session, data_service: DataService):
        self.db = db
        self.data_service = data_service

    def get_business_performance_summary(self, business_id: UUID) -> Dict[str, Any]:
        """
        Calculates high-level performance metrics for a business.
        """
        sales_df = self.data_service.get_sales_timeseries(business_id)
        inventory_df = self.data_service.get_inventory_status(business_id)

        if sales_df.empty:
            return {"status": "NO_DATA"}

        total_revenue = float(sales_df['revenue'].sum())
        total_volume = int(sales_df['volume'].sum())
        avg_daily_revenue = float(sales_df['revenue'].mean())

        # Calculate growth (if enough data)
        growth_rate = 0.0
        if len(sales_df) >= 14:
            last_7 = sales_df.iloc[-7:]['revenue'].sum()
            prev_7 = sales_df.iloc[-14:-7]['revenue'].sum()
            if prev_7 > 0:
                growth_rate = float((last_7 - prev_7) / prev_7)

        # Inventory valuation
        total_inventory_value = 0.0
        if not inventory_df.empty:
            inventory_df['value'] = inventory_df['quantity'] * inventory_df['weighted_average_cost']
            total_inventory_value = float(inventory_df['value'].sum())

        return {
            "business_id": str(business_id),
            "summary": {
                "total_revenue": total_revenue,
                "total_volume": total_volume,
                "avg_daily_revenue": avg_daily_revenue,
                "growth_rate_7d": growth_rate,
                "total_inventory_value": total_inventory_value
            }
        }
