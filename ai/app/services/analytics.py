from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID

class AnalyticsService:
    def __init__(self, db: Session, data_service):
        self.db = db
        self.ds = data_service

    def get_business_performance_summary(self, business_id: UUID):
        """
        Uses high-performance SQL views to return a comprehensive summary.
        This is much faster than calculating metrics in Python.
        """
        # 1. Fetch sales velocity insights
        velocity_query = text("""
            SELECT product_name, avg_daily_velocity, revenue_contribution
            FROM jonkai_metrics.vw_product_velocity
            WHERE business_id = :biz_id
            ORDER BY revenue_contribution DESC
            LIMIT 5
        """)

        # 2. Fetch Customer RFM segments
        rfm_query = text("""
            SELECT
                count(*) filter (where recency < 7) as active_customers,
                count(*) filter (where recency > 30) as at_risk_customers,
                avg(monetary) as avg_lifetime_value
            FROM jonkai_features.vw_customer_rfm
            WHERE business_id = :biz_id
        """)

        velocity_data = self.db.execute(velocity_query, {"biz_id": business_id}).fetchall()
        rfm_data = self.db.execute(rfm_query, {"biz_id": business_id}).fetchone()

        return {
            "top_products": [
                {"name": r[0], "velocity": float(r[1]), "revenue": float(r[2])}
                for r in velocity_data
            ],
            "customer_insights": {
                "active_last_7_days": rfm_data[0] or 0,
                "at_risk_30_days": rfm_data[1] or 0,
                "avg_lvt": float(rfm_data[2] or 0)
            }
        }
