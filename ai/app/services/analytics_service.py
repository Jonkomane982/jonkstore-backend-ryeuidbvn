from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID
import logging

logger = logging.getLogger(__name__)

class AnalyticsService:
    def __init__(self, db: Session):
        self.db = db

    def get_business_performance_summary(self, business_id: UUID):
        """
        Fetches business performance using the Materialized View for high speed.
        """
        try:
            # 1. Fetch from Materialized View (The engine we primed in pgAdmin)
            summary_query = text("""
                SELECT
                    SUM(transaction_count) as total_sales,
                    SUM(revenue) as total_revenue,
                    SUM(profit) as total_profit
                FROM jonkai_metrics.mvw_daily_kpis
                WHERE business_id = :biz_id
                AND day >= CURRENT_DATE - INTERVAL '30 days'
            """)

            # 2. Fetch Sales Velocity (Top moving products)
            velocity_query = text("""
                SELECT product_id, avg_daily_velocity, revenue_contribution
                FROM jonkai_metrics.vw_product_velocity
                WHERE business_id = :biz_id
                ORDER BY revenue_contribution DESC
                LIMIT 5
            """)

            summary = self.db.execute(summary_query, {"biz_id": business_id}).fetchone()
            velocity = self.db.execute(velocity_query, {"biz_id": business_id}).fetchall()

            return {
                "metrics": {
                    "total_sales": int(summary.total_sales or 0),
                    "total_revenue": float(summary.total_revenue or 0),
                    "total_profit": float(summary.total_profit or 0),
                },
                "top_products": [
                    {
                        "product_id": str(v.product_id),
                        "velocity": float(v.avg_daily_velocity),
                        "contribution": float(v.revenue_contribution)
                    } for v in velocity
                ]
            }
        except Exception as e:
            logger.error(f"Error fetching analytics for {business_id}: {str(e)}")
            return {"error": "Failed to fetch analytics"}
