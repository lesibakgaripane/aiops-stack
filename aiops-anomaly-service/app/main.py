import os
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import joblib
import numpy as np
from sklearn.ensemble import IsolationForest

app = FastAPI(title="AIOps Anomaly Service (Scikit-learn)")

MODEL_PATH = os.getenv("MODEL_PATH", "/app/models/anomaly_model.joblib")
_model: Optional[IsolationForest] = None


class ScorePayload(BaseModel):
    device: str
    metric: str = "cpu_usage"
    alert_id: Optional[str] = None
    time_window: str = "15m"
    value: Optional[float] = None  # numeric metric value (e.g., CPU %)


@app.on_event("startup")
def load_model_on_startup():
    global _model
    if os.path.exists(MODEL_PATH):
        try:
            _model = joblib.load(MODEL_PATH)
        except Exception:
            _model = None


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "aiops-anomaly-service",
        "model_loaded": _model is not None,
        "model_path": MODEL_PATH,
    }


@app.post("/train_dummy_model")
async def train_dummy_model():
    """
    Train a simple IsolationForest model on synthetic CPU-like data.
    This is scaffolding: later you can replace it with real telemetry-based training.
    """

    # Synthetic: most points around 30-60 (normal), few outliers at 90-100
    normal = np.random.normal(loc=45.0, scale=10.0, size=(500, 1))
    high = np.random.normal(loc=95.0, scale=3.0, size=(20, 1))
    X = np.vstack([normal, high])

    model = IsolationForest(contamination=0.05, random_state=42)
    model.fit(X)

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    joblib.dump(model, MODEL_PATH)

    global _model
    _model = model

    return {"status": "trained", "samples": int(X.shape[0]), "model_path": MODEL_PATH}


def heuristic_risk(device: str, metric: str) -> (float, str, str):
    """
    Fallback heuristic (your original logic) if no model/value is available.
    """
    device_lower = device.lower()
    base_score = 0.3  # default low

    if "core" in device_lower:
        base_score = 0.8
    elif "rb" in device_lower or "jd" in device_lower:
        base_score = 0.6

    if base_score >= 0.8:
        label = "high"
    elif base_score >= 0.5:
        label = "medium"
    else:
        label = "low"

    note = "[ANOMALY-HEURISTIC] Using device-name heuristic (no model/value)."
    return base_score, label, note


@app.post("/score")
async def score(payload: ScorePayload):
    """
    Risk scoring:
    - If a trained model exists AND value is provided -> use IsolationForest.
    - Otherwise -> use the original heuristic based on device name.
    """
    global _model

    # Case 1: model + numeric value available
    if _model is not None and payload.value is not None:
        X = np.array([[payload.value]], dtype=float)

        # IsolationForest: smaller (more negative) score = more anomalous
        raw_score = _model.decision_function(X)[0]
        # Map to a 0..1 anomaly score (inverted: 1 = most risky)
        anomaly_score = float(1.0 - (raw_score + 1.0) / 2.0)
        anomaly_score = max(0.0, min(1.0, anomaly_score))

        if anomaly_score >= 0.8:
            label = "high"
        elif anomaly_score >= 0.5:
            label = "medium"
        else:
            label = "low"

        note = "[ANOMALY-ML] Scored using IsolationForest on metric value."

        return {
            "device": payload.device,
            "metric": payload.metric,
            "time_window": payload.time_window,
            "value": payload.value,
            "risk_score": anomaly_score,
            "risk_label": label,
            "note": note,
        }

    # Case 2: fallback to heuristic
    base_score, label, note = heuristic_risk(payload.device, payload.metric)

    return {
        "device": payload.device,
        "metric": payload.metric,
        "time_window": payload.time_window,
        "value": payload.value,
        "risk_score": base_score,
        "risk_label": label,
        "note": note,
    }
