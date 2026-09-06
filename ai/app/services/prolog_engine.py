import json
from typing import List, Dict, Any, Optional
from uuid import UUID
from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.models.schemas import RuleDefinition, RuleResult, ModelRun
from app.db.repository import BaseRepository
from structlog import get_logger

logger = get_logger(__name__)

try:
    from pyswip import Prolog as _Prolog
    _SWIPL_AVAILABLE = True
    _SWIPL_ERROR = None
except Exception as _e:
    _SWIPL_AVAILABLE = False
    _SWIPL_ERROR = str(_e)

class PrologEngine:
    """
    JONKAI Prolog Rule Engine.
    Handles the conversion of signals to facts and execution of business rules.
    """
    def __init__(self):
        if not _SWIPL_AVAILABLE:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "Prolog engine unavailable",
                    "message": "SWI-Prolog is not installed or not found on this server.",
                    "hint": "Install SWI-Prolog (https://www.swi-prolog.org/) and ensure it is on PATH to enable deterministic rule evaluation.",
                    "root_cause": _SWIPL_ERROR
                }
            )
        self.prolog = _Prolog()
        self._initialized_rules = set()

    def evaluate(
        self,
        db: Session,
        business_id: UUID,
        category: str,
        signal: Dict[str, Any],
        model_run_id: Optional[UUID] = None
    ):
        return self.evaluate_rules(db, business_id, category, signal, model_run_id)

    def _sanitize_predicate(self, text: str) -> str:
        """Basic sanitization to prevent Prolog injection."""
        # In a production system, this would be much more robust.
        # We ensure only approved rules from the DB are used.
        return text.replace("'", "''").strip()

    def _assert_signal_facts(self, signal: Dict[str, Any]):
        """
        Converts a structured signal into Prolog facts.
        Example: {"product_id": "...", "quantity": 4} -> fact(product, '...'), fact(quantity, 4).
        """
        for key, value in signal.items():
            if isinstance(value, (str, int, float, bool)):
                # fact(key, value).
                fact_str = f"signal_fact({key}, {repr(value)})"
                self.prolog.assertz(fact_str)

    def _clear_facts(self):
        """Removes all dynamic signal facts after evaluation."""
        self.prolog.retractall("signal_fact(_, _)")

    def evaluate_rules(
        self,
        db: Session,
        business_id: UUID,
        category: str,
        signal: Dict[str, Any],
        model_run_id: Optional[UUID] = None
    ) -> List[Dict[str, Any]]:
        """
        Loads business-specific rules and evaluates them against the signal facts.
        """
        # 1. Load active, approved rules for the business and category
        rules = db.query(RuleDefinition).filter(
            RuleDefinition.business_id == business_id,
            RuleDefinition.category == category,
            RuleDefinition.is_enabled == True,
            RuleDefinition.approval_status == 'APPROVED'
        ).order_by(RuleDefinition.priority.desc()).all()

        if not rules:
            logger.info("No active approved rules found", business_id=str(business_id), category=category)
            return []

        # 2. Ensure rules are loaded into the Prolog interpreter
        for rule in rules:
            rule_key = f"{rule.id}_{rule.rule_version}"
            if rule_key not in self._initialized_rules:
                if rule.prolog_predicate:
                    try:
                        self.prolog.assertz(rule.prolog_predicate)
                        self._initialized_rules.add(rule_key)
                    except Exception as e:
                        logger.error("Failed to load rule predicate", rule_id=str(rule.id), error=str(e))

        # 3. Assert facts from signal
        self._assert_signal_facts(signal)

        results = []
        try:
            # 4. Evaluate each rule
            # The rule predicate in the DB should be designed to be queried.
            # Example: check_low_stock(Result, Evidence)
            for rule in rules:
                # We expect the rule to define a predicate name in its metadata or derived from code
                # For this implementation, we assume rule_code is the predicate name.
                query_str = f"{rule.rule_code}(Result, Evidence)"

                try:
                    query_results = list(self.prolog.query(query_str))

                    for q_res in query_results:
                        res_code = str(q_res.get("Result", "UNKNOWN"))
                        evidence = q_res.get("Evidence", {})

                        # Handle Prolog atom conversion if necessary
                        if hasattr(evidence, 'decode'): evidence = evidence.decode()
                        if isinstance(evidence, str) and (evidence.startswith('{') or evidence.startswith('[')):
                            try:
                                evidence = json.loads(evidence)
                            except: pass

                        # 5. Persist Rule Result
                        rule_result = RuleResult(
                            business_id=business_id,
                            rule_id=rule.id,
                            rule_version=rule.rule_version,
                            input_signal=signal,
                            matched_conditions=rule.conditions,
                            result_code=res_code,
                            evidence=evidence,
                            model_run_id=model_run_id
                        )
                        db.add(rule_result)

                        results.append({
                            "rule_code": rule.rule_code,
                            "rule_version": rule.rule_version,
                            "result": res_code,
                            "evidence": evidence,
                            "priority": rule.priority
                        })
                except Exception as e:
                    logger.error("Error querying Prolog rule", rule_code=rule.rule_code, error=str(e))

            db.commit()
        finally:
            # 6. Cleanup facts for the next run
            self._clear_facts()

        return results
