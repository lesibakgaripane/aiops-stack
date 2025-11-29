from typing import Any, Text, Dict, List, Optional
import os
import requests

from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher

# --- ChatGPT fallback (requests-based, no httpx) ---
CHATGPT_FALLBACK_THRESHOLD = float(os.getenv("CHATGPT_FALLBACK_THRESHOLD", "0.70"))
ML_GATEWAY_URL = os.getenv("ML_GATEWAY_URL", "http://aiops-ml-gateway:9000")
CHATGPT_PROXY_URL = os.getenv("CHATGPT_PROXY_URL", f"{ML_GATEWAY_URL}/ai/chatgpt")
CHATGPT_TIMEOUT = float(os.getenv("CHATGPT_TIMEOUT", "25"))

def _call_chatgpt_via_gateway_sync(message: str, context: str = "", conversation_id: str | None = None):
    payload = {"message": message, "context": context, "conversation_id": conversation_id}
    try:
        r = requests.post(CHATGPT_PROXY_URL, json=payload, timeout=CHATGPT_TIMEOUT)
        # ml-gateway returns json even on errors
        try:
            data = r.json()
        except Exception:
            return None
        if isinstance(data, dict) and data.get("answer"):
            return data["answer"]
        # passthrough error format: {error:..., status_code:...}
        if isinstance(data, dict) and data.get("status_code", 200) >= 400:
            return None
        return None
    except Exception:
        return None


# URL of the ML gateway inside the Docker network
AIOPS_ML_GATEWAY_URL = os.getenv(
    "AIOPS_ML_GATEWAY_URL",
    "http://aiops-ml-gateway:9000",
)


def call_rag_brain(question: str, context: Optional[Dict[str, Any]] = None) -> str:
    """Call the RAG brain via the ML gateway."""
    url = f"{AIOPS_ML_GATEWAY_URL}/ai/rag/query"
    payload: Dict[str, Any] = {
        "question": question,
        "context": context or {},
    }

    try:
        resp = requests.post(url, json=payload, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        return data.get(
            "answer",
            "Sorry, I could not generate an answer from the AIOps RAG brain.",
        )
    except Exception as e:
        return f"[RAG ERROR] Could not reach RAG service: {e}"


def call_anomaly_brain(
    device: str,
    metric: str = "cpu_usage",
    alert_id: Optional[str] = None,
    time_window: str = "15m",
    value: Optional[float] = None,
) -> str:
    """Call the anomaly brain via the ML gateway."""
    url = f"{AIOPS_ML_GATEWAY_URL}/ai/anomaly/score"
    payload: Dict[str, Any] = {
        "device": device,
        "metric": metric,
        "alert_id": alert_id,
        "time_window": time_window,
    }
    # Only send value if we actually have one
    if value is not None:
        payload["value"] = value

    try:
        resp = requests.post(url, json=payload, timeout=15)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return f"[ANOMALY ERROR] Could not reach anomaly service: {e}"

    risk_score = data.get("risk_score", 0.0)
    risk_label = data.get("risk_label", "unknown")
    note = data.get("note", "")

    # Be defensive about types here
    try:
        score_str = f"{float(risk_score):.2f}"
    except Exception:
        score_str = str(risk_score)

    return (
        f"Anomaly risk for device '{device}' on metric '{metric}' "
        f"is **{risk_label}** (score={score_str}). {note}"
    )


class ActionAIOpsRAGAnswer(Action):
    """Rasa action to answer AIOps questions via RAG brain."""

    def name(self) -> Text:
        return "action_aiops_rag_answer"


    def run(
        self,
        dispatcher: CollectingDispatcher,
        tracker: Tracker,
        domain: Dict[Text, Any],
    ) -> List[Dict[Text, Any]]:

        try:
            user_msg = tracker.latest_message.get("text", "")

            device = tracker.get_slot("device_name")
            metric = tracker.get_slot("metric")
            alert_id = tracker.get_slot("alert_id")

            context: Dict[str, Any] = {
                "device": device,
                "metric": metric,
                "alert_id": alert_id,
            }

            # 1) RAG first
            result_text = call_rag_brain(user_msg, context)

            # 2) Fallback if RAG looks bad
            rag_bad = (
                (not result_text)
                or (isinstance(result_text, str) and (
                    result_text.startswith("[RAG ERROR]")
                    or "could not generate an answer" in result_text.lower()
                    or "sorry, i could not" in result_text.lower()
                ))
            )

            if rag_bad:
                fb = _call_chatgpt_via_gateway_sync(
                    message=user_msg,
                    context=str(context),
                    conversation_id=getattr(tracker, "sender_id", None),
                )
                if fb:
                    result_text = fb

            dispatcher.utter_message(text=result_text)
            return []

        except Exception as e:
            dispatcher.utter_message(
                text=f"[ACTION ERROR] Failed to run RAG action: {e}"
            )
            return []

class ActionAIOpsAnomalyScore(Action):
    """Rasa action to score an alert / device risk via anomaly brain."""

    def name(self) -> Text:
        return "action_aiops_anomaly_score"

    def run(
        self,
        dispatcher: CollectingDispatcher,
        tracker: Tracker,
        domain: Dict[Text, Any],
    ) -> List[Dict[Text, Any]]:

        try:
            user_msg = tracker.latest_message.get("text", "") or ""

            device = tracker.get_slot("device_name") or "UNKNOWN"
            metric = tracker.get_slot("metric") or "cpu_usage"
            alert_id = tracker.get_slot("alert_id")

            # Try to extract a numeric value from the text (e.g. "95%")
            value: Optional[float] = None
            for token in user_msg.replace("%", " ").split():
                try:
                    value = float(token)
                    break
                except ValueError:
                    continue

            result_text = call_anomaly_brain(
                device=device,
                metric=metric,
                alert_id=alert_id,
                time_window="15m",
                value=value,
            )
            dispatcher.utter_message(text=result_text)
            return []

        except Exception as e:
            dispatcher.utter_message(
                text=f"[ACTION ERROR] Failed to run anomaly action: {e}"
            )
            return []
