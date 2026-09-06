import json
from typing import List, Dict, Any, Optional
from uuid import UUID
from datetime import datetime
from openai import OpenAI
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.models.schemas import ChatThread, ChatMessage, Recommendation, RuleResult
from app.config.settings import settings
from app.db.session import engine
from structlog import get_logger

logger = get_logger(__name__)

class ChatService:
    """
    JONKAI Conversational Layer.
    Provides natural language interaction using OpenAI GPT-4o.
    Supports Multimodal input (Vision), Function Calling (Tools), and Grounding.
    """
    def __init__(self):
        if settings.OPENAI_API_KEY:
            self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
        else:
            self.client = None
            logger.warning("OpenAI API key not configured. Conversational layer will be unavailable.")

    def get_or_create_thread(
        self,
        db: Session,
        business_id: UUID,
        user_id: UUID,
        thread_id: Optional[UUID] = None,
        title: Optional[str] = None,
    ) -> ChatThread:
        """Retrieves an owned thread by ID, or creates/fetches the latest one."""
        if thread_id is not None:
            thread = db.query(ChatThread).filter(
                ChatThread.id == thread_id,
                ChatThread.business_id == business_id,
                ChatThread.user_id == user_id,
            ).first()
            if not thread:
                raise ValueError("Thread not found for this business and user")
            return thread

        thread = db.query(ChatThread).filter(
            ChatThread.business_id == business_id,
            ChatThread.user_id == user_id
        ).order_by(ChatThread.last_message_at.desc()).first()

        if not thread:
            thread = ChatThread(
                business_id=business_id,
                user_id=user_id,
                title=title or "New Conversation"
            )
            db.add(thread)
            db.commit()
            db.refresh(thread)

        return thread

    def _get_product_details(self, business_id: UUID, identifier: str) -> Dict[str, Any]:
        """
        Tool: Lookup product details and stock by ID, SKU, or Barcode.
        Enforces tenant isolation by requiring business_id.
        """
        # Search in products (by ID or SKU) or join with barcodes
        query = """
            SELECT p.product_id, p.name, p.sku, p.selling_price, i.quantity, i.weighted_average_cost
            FROM jonkai_core.products p
            LEFT JOIN jonkai_core.inventory i ON p.product_id = i.product_id
            LEFT JOIN jonkai_core.product_barcodes b ON p.product_id = b.product_id
            WHERE p.business_id = :business_id
            AND (p.product_id::text = :id OR p.sku = :id OR b.barcode = :id)
            LIMIT 1
        """
        try:
            with engine.connect() as conn:
                result = conn.execute(text(query), {
                    "business_id": str(business_id),
                    "id": identifier
                }).mappings().first()

                if result:
                    return dict(result)
                return {"error": f"Product with identifier '{identifier}' not found in your inventory."}
        except Exception as e:
            logger.error("Product lookup tool failed", error=str(e))
            return {"error": "Internal analytical database error during lookup."}

    def _get_business_context(self, db: Session, business_id: UUID) -> str:
        """Gathers active signals and rule results to ground the LLM."""
        recs = db.query(Recommendation).filter(
            Recommendation.business_id == business_id,
            Recommendation.status == 'ACTIVE'
        ).limit(5).all()

        rules = db.query(RuleResult).filter(
            RuleResult.business_id == business_id
        ).order_by(RuleResult.evaluated_at.desc()).limit(5).all()

        context = "Current Business Intelligence State:\n"
        if recs:
            context += "\nRecent High-Priority Recommendations:\n"
            for r in recs:
                context += f"- [{r.type}] {r.title}: {r.reasoning}\n"
        if rules:
            context += "\nRecent Rule Engine Results:\n"
            for rule in rules:
                context += f"- Policy Check: {rule.result_code}. Logic Evidence: {json.dumps(rule.evidence)}\n"

        return context

    def generate_response(self, db: Session, thread_id: UUID, user_message: str, image_b64: Optional[str] = None) -> str:
        """
        Processes user query with grounding, tool execution, and vision processing.
        """
        if not self.client:
            return "Jonk AI is currently offline. Please configure the OpenAI API key."

        thread = db.query(ChatThread).get(thread_id)
        if not thread:
            raise ValueError("Thread not found")

        # 1. Prepare User Content (Multimodal)
        user_content = [{"type": "text", "text": user_message}]
        if image_b64:
            user_content.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}
            })

        # Record User Message
        db.add(ChatMessage(
            thread_id=thread_id,
            role="user",
            content=user_message if not image_b64 else f"[Image Uploaded] {user_message}"
        ))

        # 2. Define Tools (Functions)
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "get_product_details",
                    "description": "Fetch stock levels, prices, and status for a product using its ID, SKU, or a scanned Barcode.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "identifier": {"type": "string", "description": "The Product UUID, SKU string, or the numeric/alphanumeric Barcode string."}
                        },
                        "required": ["identifier"]
                    }
                }
            }
        ]

        # 3. Assemble Grounded Prompt
        business_context = self._get_business_context(db, thread.business_id)

        messages = [
            {
                "role": "system",
                "content": f"""You are Jonk AI, the expert intelligence assistant for JonkStore POS.
Your goal is to provide data-driven insights to business owners.

{business_context}

CORE CAPABILITIES:
- Identify products and read barcodes from images provided by the user.
- Query real-time inventory and pricing using the 'get_product_details' tool.
- Answer complex questions about business health, sales trends, and security.

GUIDELINES:
- If an image is provided, identify any visible products or barcodes.
- If identification is successful or an identifier is mentioned, ALWAYS use 'get_product_details' to check the actual status in the system.
- Mention specific product names and exact stock quantities in your response.
- Be professional, accurate, and concise.
"""
            }
        ]

        # Load history
        history = db.query(ChatMessage).filter(
            ChatMessage.thread_id == thread_id
        ).order_by(ChatMessage.created_at.desc()).limit(10).all()
        for m in reversed(history):
            messages.append({"role": m.role, "content": m.content})

        # Current message
        messages.append({"role": "user", "content": user_content})

        try:
            # 4. Initial AI Request (Evaluates tools/vision)
            response = self.client.chat.completions.create(
                model="gpt-4o", # gpt-4o is required for Vision + Tools
                messages=messages,
                tools=tools,
                tool_choice="auto"
            )

            assistant_msg = response.choices[0].message

            # 5. Process Tool Calls
            if assistant_msg.tool_calls:
                messages.append(assistant_msg)
                for tool_call in assistant_msg.tool_calls:
                    if tool_call.function.name == "get_product_details":
                        args = json.loads(tool_call.function.arguments)
                        # Secure lookup
                        data = self._get_product_details(thread.business_id, args["identifier"])

                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "name": "get_product_details",
                            "content": json.dumps(data)
                        })

                # Second call to synthesize results
                final_response = self.client.chat.completions.create(
                    model="gpt-4o",
                    messages=messages
                )
                assistant_text = final_response.choices[0].message.content
            else:
                assistant_text = assistant_msg.content

            # 6. Save Assistant Response
            db.add(ChatMessage(thread_id=thread_id, role="assistant", content=assistant_text))
            thread.last_message_at = datetime.now()
            db.commit()

            return assistant_text

        except Exception as e:
            logger.error("Jonk AI Vision/Tool execution failed", error=str(e))
            db.rollback()
            return "I encountered an error identifying that product or processing your request. Please try again."
