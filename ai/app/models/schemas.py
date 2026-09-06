from sqlalchemy import Column, String, Integer, Numeric, Boolean, DateTime, ForeignKey, JSON, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.db.session import Base

# --- Schema: jonkai_ingest ---

class IngestPayload(Base):
    __tablename__ = "payloads"
    __table_args__ = {"schema": "jonkai_ingest"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    source_system = Column(String, nullable=False)
    source_record_id = Column(Text, nullable=False)
    source_version = Column(Integer, default=1)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    event_type = Column(String, nullable=False)
    payload = Column(JSON, nullable=False)
    payload_hash = Column(Text, nullable=False)
    idempotency_key = Column(Text)
    received_at = Column(DateTime(timezone=True), server_default=func.now())
    status = Column(String, default="RECEIVED")
    processed_at = Column(DateTime(timezone=True))
    error_message = Column(Text)
    attempt_count = Column(Integer, default=0)

# --- Schema: jonkai_core ---

class CoreBusiness(Base):
    __tablename__ = "businesses"
    __table_args__ = {"schema": "jonkai_core"}

    business_id = Column(UUID(as_uuid=True), primary_key=True)
    name = Column(Text, nullable=False)
    industry = Column(Text)
    source_version = Column(Integer, nullable=False)
    ingested_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)
    payload = Column(JSON)

class CoreProduct(Base):
    __tablename__ = "products"
    __table_args__ = {"schema": "jonkai_core"}

    product_id = Column(UUID(as_uuid=True), primary_key=True)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    category_id = Column(UUID(as_uuid=True))
    name = Column(Text, nullable=False)
    sku = Column(Text)
    selling_price = Column(Numeric(19, 4))
    source_version = Column(Integer, nullable=False)
    ingested_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)

class CoreSale(Base):
    __tablename__ = "sales"
    __table_args__ = {"schema": "jonkai_core"}

    sale_id = Column(UUID(as_uuid=True), primary_key=True)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    branch_id = Column(UUID(as_uuid=True), nullable=False)
    customer_id = Column(UUID(as_uuid=True))
    employee_id = Column(UUID(as_uuid=True))
    total_amount = Column(Numeric(19, 4), nullable=False)
    sale_date = Column(DateTime(timezone=True), nullable=False)
    source_version = Column(Integer, nullable=False)
    ingested_at = Column(DateTime(timezone=True), server_default=func.now())
    status = Column(Text)

class CoreSaleItem(Base):
    __tablename__ = "sale_items"
    __table_args__ = {"schema": "jonkai_core"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    sale_id = Column(UUID(as_uuid=True), ForeignKey("jonkai_core.sales.sale_id"), nullable=False)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    product_id = Column(UUID(as_uuid=True), nullable=False)
    quantity = Column(Numeric(15, 3), nullable=False)
    unit_price = Column(Numeric(19, 4), nullable=False)
    unit_cost_at_sale = Column(Numeric(19, 4))

# --- Schema: jonkai_analytics ---

class FactSale(Base):
    __tablename__ = "fact_sales"
    __table_args__ = (
        UniqueConstraint('business_id', 'source_sale_id', name='idx_fact_sales_unq'),
        {"schema": "jonkai_analytics"}
    )

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    branch_id = Column(UUID(as_uuid=True))
    date_key = Column(Integer)
    time_key = Column(Integer)
    sale_timestamp = Column(DateTime(timezone=True), nullable=False)
    total_amount = Column(Numeric(19, 4), nullable=False)
    cost_amount = Column(Numeric(19, 4), nullable=False)
    gross_profit = Column(Numeric(19, 4))
    source_sale_id = Column(UUID(as_uuid=True), nullable=False)

# --- Schema: jonkai_rules ---

class RuleDefinition(Base):
    __tablename__ = "definitions"
    __table_args__ = {"schema": "jonkai_rules"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    rule_code = Column(Text, nullable=False)
    name = Column(Text, nullable=False)
    category = Column(Text)
    priority = Column(Integer, default=100)
    is_enabled = Column(Boolean, default=True)
    rule_version = Column(Integer, nullable=False, default=1)
    source = Column(Text)
    approval_status = Column(String, default="PENDING")
    conditions = Column(JSON, nullable=False)
    actions = Column(JSON, nullable=False)
    prolog_predicate = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class RuleResult(Base):
    __tablename__ = "rule_results"
    __table_args__ = {"schema": "jonkai_rules"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    rule_id = Column(UUID(as_uuid=True), ForeignKey("jonkai_rules.definitions.id"))
    rule_version = Column(Integer, nullable=False)
    input_signal = Column(JSON, nullable=False)
    matched_conditions = Column(JSON)
    result_code = Column(Text, nullable=False)
    evidence = Column(JSON)
    evaluated_at = Column(DateTime(timezone=True), server_default=func.now())
    model_run_id = Column(UUID(as_uuid=True))

# --- Schema: jonkai_ai ---

class ModelRun(Base):
    __tablename__ = "model_runs"
    __table_args__ = {"schema": "jonkai_ai"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    model_name = Column(Text, nullable=False)
    model_version = Column(Text, nullable=False)
    run_timestamp = Column(DateTime(timezone=True), server_default=func.now())
    input_feature_set = Column(Text)
    performance_metrics = Column(JSON)

class Prediction(Base):
    __tablename__ = "predictions"
    __table_args__ = {"schema": "jonkai_ai"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    run_id = Column(UUID(as_uuid=True), ForeignKey("jonkai_ai.model_runs.id"))
    target_entity_type = Column(Text, nullable=False)
    target_entity_id = Column(UUID(as_uuid=True), nullable=False)
    prediction_type = Column(Text, nullable=False)
    forecast_start = Column(DateTime)
    forecast_end = Column(DateTime)
    predicted_value = Column(Numeric(19, 4), nullable=False)
    actual_value = Column(Numeric(19, 4))
    confidence_score = Column(Numeric(3, 2))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Recommendation(Base):
    __tablename__ = "recommendations"
    __table_args__ = {"schema": "jonkai_ai"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    type = Column(Text, nullable=False)
    priority = Column(String)
    title = Column(Text, nullable=False)
    reasoning = Column(Text, nullable=False)
    status = Column(String, default="ACTIVE")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# --- Schema: jonkai_chat ---

class ChatThread(Base):
    __tablename__ = "threads"
    __table_args__ = {"schema": "jonkai_chat"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    business_id = Column(UUID(as_uuid=True), nullable=False)
    user_id = Column(UUID(as_uuid=True), nullable=False)
    title = Column(Text)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    last_message_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class ChatMessage(Base):
    __tablename__ = "messages"
    __table_args__ = {"schema": "jonkai_chat"}

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    thread_id = Column(UUID(as_uuid=True), ForeignKey("jonkai_chat.threads.id", ondelete="CASCADE"), nullable=False)
    role = Column(String, nullable=False) # system, user, assistant, tool
    content = Column(Text, nullable=False)
    tool_calls = Column(JSON)
    token_usage_estimate = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
