from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID
from typing import Optional, Dict, Any
from app.db.session import get_db
from app.services.analytics import AnalyticsService
from app.services.forecasting import ForecastingService
from app.services.anomaly_detection import AnomalyDetectionService
from app.services.recommendations import RecommendationService
from app.services.chat_service import ChatService
from app.services.prolog_engine import PrologEngine
from app.db.data_service import DataService
from pydantic import BaseModel

app = FastAPI(
    title="JonkAI Intelligence Engine",
    description="Deterministic Reasoning (Prolog) + Statistical Forecasting (Python) + Natural Language (OpenAI)",
    version="1.0.0"
)


@app.get("/")
def root():
    """Small discovery endpoint for browsers and hosting platforms."""
    return {
        "service": "JonkAI Intelligence Engine",
        "status": "active",
        "health": "/health",
        "docs": "/docs",
    }

# --- Request Models ---

class ChatRequest(BaseModel):
    business_id: UUID
    user_id: UUID
    message: str
    thread_id: Optional[UUID] = None
    image_b64: Optional[str] = None

class BusinessRequest(BaseModel):
    business_id: UUID

class RuleEvaluationRequest(BaseModel):
    business_id: UUID
    category: str
    signal: Dict[str, Any]
    model_run_id: Optional[UUID] = None

# --- Endpoints ---

@app.get("/health")
def health_check():
    return {"status": "active", "engine": "JonkAI"}

@app.post("/analytics/summary")
def get_business_summary(req: BusinessRequest, db: Session = Depends(get_db)):
    ds = DataService(db)
    service = AnalyticsService(db, ds)
    return service.get_business_performance_summary(req.business_id)

@app.post("/forecast/sales")
def forecast_sales(req: BusinessRequest, horizon: int = 7, db: Session = Depends(get_db)):
    ds = DataService(db)
    service = ForecastingService(db, ds)
    return service.forecast_sales(req.business_id, horizon_days=horizon)

@app.post("/anomalies/detect")
def detect_anomalies(req: BusinessRequest, db: Session = Depends(get_db)):
    ds = DataService(db)
    service = AnomalyDetectionService(db, ds)
    return service.detect_sales_anomalies(req.business_id)

@app.post("/recommendations/generate")
def generate_recommendations(req: BusinessRequest, db: Session = Depends(get_db)):
    ds = DataService(db)
    service = RecommendationService(db, ds)
    return service.generate_inventory_recommendations(req.business_id)

@app.post("/rules/evaluate")
def evaluate_business_rules(req: RuleEvaluationRequest, db: Session = Depends(get_db)):
    engine = PrologEngine()
    return engine.evaluate(
        db=db,
        business_id=req.business_id,
        category=req.category,
        signal=req.signal,
        model_run_id=req.model_run_id
    )

@app.post("/chat/message")
def chat_with_jonk(req: ChatRequest, db: Session = Depends(get_db)):
    service = ChatService()

    # If thread_id is missing, get or create one using business/user context
    thread = service.get_or_create_thread(
        db=db,
        business_id=req.business_id,
        user_id=req.user_id,
        thread_id=req.thread_id
    )

    response_text = service.generate_response(
        db=db,
        thread_id=thread.id,
        user_message=req.message,
        image_b64=req.image_b64
    )

    return {
        "response": response_text,
        "thread_id": str(thread.id)
    }
