# JONKAI Database Architecture
**Principal AI Systems Architect Documentation**

## 1. Purpose
JONKAI PostgreSQL is the **Intelligence Layer** of the JonkStore ecosystem. It is strictly decoupled from the operational POS database (`JonkStore_Postgre.sql`). Its primary roles are:
*   **Historical Preservation**: Storing immutable snapshots of business activity.
*   **Machine Learning (Python)**: Serving as a Feature Store for forecasting and anomaly detection.
*   **Symbolic Reasoning (Prolog)**: Providing a fact base for inventory and supply chain logic.
*   **Natural Language (OpenAI)**: Storing conversation context and tool-execution metadata.

## 2. Logical Layering
The database is organized into specialized namespaces (schemas) to enforce data governance:
*   `jonkai_ingest`: Landing zone for raw events from SQLite, Firestore, and operational Postgres.
*   `jonkai_core`: Normalized historical mirror of POS entities.
*   `jonkai_analytics`: Star-schema optimized for OLAP (Facts and Dimensions).
*   `jonkai_features`: Calculated metrics (velocity, churn, volatility) for AI model inputs.
*   `jonkai_ai`: The "Brain" - stores predictions, recommendations, and model performance logs.
*   `jonkai_chat`: Memory for AI assistant conversations and multi-tool orchestration.

## 3. Data Flow & Lineage
Every record in JONKAI contains a **Source Lineage Triplet**:
1.  `source_system`: Identifying where the data originated (e.g., `POS_OFFLINE_SQLITE`).
2.  `source_record_id`: The original UUID from the source.
3.  `source_version`: Tracking changes to the same entity over time.

**Idempotency**: Unique constraints on this triplet ensure that re-processing sync events never creates duplicate analytical facts.

## 4. Multi-Tenant Isolation
Tenancy is structurally enforced using **PostgreSQL Row-Level Security (RLS)**. 
*   All business-scoped tables have a `business_id`.
*   Policies ensure that an AI service session bound to `Business A` cannot accidentally read or calculate metrics based on `Business B` data.

## 5. Integration Boundaries
### Python (Machine Learning)
Python services access the `jonkai_features` schema to retrieve training data and write results back to `jonkai_ai.predictions`. They use the `jonkai_analytics` star schema for trend analysis.

### Prolog (Reasoning)
Prolog engines query the `jonkai_knowledge.base` and `jonkai_core` tables. These tables are structured to be easily mapped to Prolog predicates (e.g., `product(ID, Price, Stock)`).

### OpenAI (Natural Language)
The `jonkai_chat` schema persists user intent, conversation history, and costs. It tracks which "tools" (Python/Prolog functions) were called by the LLM to provide an answer.

## 6. Performance & Scale
*   **Partitioning**: Fact tables (`fact_sales`) and raw events are designed for time-based partitioning as volume grows.
*   **Indexing**: GIN indexes are used for `JSONB` fields in the Knowledge Base to allow rapid searching of unstructured business rules.
*   **BRIN Indexes**: Applied to append-only timestamped logs to keep index sizes manageable.

## 7. Retention Policy
*   **Ingest Logs**: 90 days (for debugging pipeline failures).
*   **Analytical Facts**: Indefinite (for long-term trend analysis).
*   **AI Outputs**: 1 year or until deprecated by a newer model version.
