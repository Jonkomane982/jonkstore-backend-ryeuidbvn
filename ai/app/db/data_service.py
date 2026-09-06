import pandas as pd
from sqlalchemy import text
from sqlalchemy.orm import Session
from uuid import UUID
from typing import Optional
from app.db.session import engine

class DataService:
    def __init__(self, db: Session):
        self.db = db

    def get_sales_timeseries(self, business_id: UUID, branch_id: Optional[UUID] = None) -> pd.DataFrame:
        """
        Fetches historical sales time series for a business/branch.
        Uses jonkai_core.sales as the historical mirror.
        """
        query = """
            SELECT sale_date::date as date, SUM(total_amount) as revenue, COUNT(*) as volume
            FROM jonkai_core.sales
            WHERE business_id = :business_id
        """
        params = {"business_id": str(business_id)}

        if branch_id:
            query += " AND branch_id = :branch_id"
            params["branch_id"] = str(branch_id)

        query += " GROUP BY sale_date::date ORDER BY date ASC"

        df = pd.read_sql(text(query), engine, params=params)
        df['date'] = pd.to_datetime(df['date'])
        return df

    def get_inventory_status(self, business_id: UUID) -> pd.DataFrame:
        """
        Fetches current inventory levels and WAC from the core mirror.
        """
        query = """
            SELECT i.product_id, p.name, i.branch_id, i.quantity, i.weighted_average_cost
            FROM jonkai_core.inventory i
            JOIN jonkai_core.products p ON i.product_id = p.product_id
            WHERE i.business_id = :business_id
        """
        return pd.read_sql(text(query), engine, params={"business_id": str(business_id)})

    def get_product_sales_velocity(self, business_id: UUID, days: int = 30) -> pd.DataFrame:
        """
        Calculates average daily sales per product over a window.
        """
        query = """
            SELECT product_id, SUM(quantity) / :days as avg_daily_velocity
            FROM jonkai_core.sale_items
            JOIN jonkai_core.sales ON sale_items.sale_id = sales.sale_id
            WHERE sales.business_id = :business_id
            AND sales.sale_date > CURRENT_DATE - interval '1 day' * :days
            GROUP BY product_id
        """
        return pd.read_sql(text(query), engine, params={"business_id": str(business_id), "days": days})
