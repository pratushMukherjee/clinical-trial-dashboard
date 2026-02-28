"""
deviation_classifier.py -- Protocol Deviation text classifier for inference
Called from R via reticulate.

Usage from R:
  reticulate::source_python("python/deviation_classifier.py")
  result <- classify_deviation("Subject missed Visit 4")
"""

import os
import pickle
import numpy as np


class DeviationClassifier:
    """Text classifier for protocol deviations using TF-IDF + Logistic Regression."""

    def __init__(self, pipeline_path="models/deviation_pipeline.pkl"):
        if os.path.exists(pipeline_path):
            with open(pipeline_path, "rb") as f:
                self.pipeline = pickle.load(f)
            self.categories = list(self.pipeline.named_steps["clf"].classes_)
            self.loaded = True
        else:
            self.pipeline = None
            self.categories = [
                "INFORMED CONSENT",
                "INCLUSION/EXCLUSION CRITERIA",
                "STUDY PROCEDURES",
                "STUDY TREATMENT/MEDICATION",
                "VISIT SCHEDULE",
                "SAFETY REPORTING",
                "OTHER",
            ]
            self.loaded = False

    def classify(self, text):
        """Classify a single deviation description.

        Returns dict with:
          - category: predicted category string
          - confidence: float 0-1
          - probabilities: dict mapping category -> probability
        """
        if not self.loaded:
            return self._keyword_fallback(text)

        probabilities = self.pipeline.predict_proba([text])[0]
        prediction = self.pipeline.predict([text])[0]
        confidence = float(max(probabilities))

        return {
            "category": str(prediction),
            "confidence": round(confidence, 4),
            "probabilities": {
                cat: round(float(prob), 4)
                for cat, prob in zip(self.categories, probabilities)
            },
        }

    def classify_batch(self, texts):
        """Classify multiple deviation descriptions."""
        if not self.loaded:
            return [self._keyword_fallback(t) for t in texts]

        predictions = self.pipeline.predict(texts)
        probabilities = self.pipeline.predict_proba(texts)

        return [
            {
                "category": str(pred),
                "confidence": round(float(max(prob)), 4),
                "probabilities": {
                    cat: round(float(p), 4)
                    for cat, p in zip(self.categories, prob)
                },
            }
            for pred, prob in zip(predictions, probabilities)
        ]

    def _keyword_fallback(self, text):
        """Keyword-based classification when no model is available."""
        text_lower = text.lower()

        keyword_map = {
            "INFORMED CONSENT": ["consent", "icf", "signed", "signature", "witness"],
            "INCLUSION/EXCLUSION CRITERIA": [
                "inclusion", "exclusion", "eligibility", "criteria",
                "enrolled", "bmi", "pregnancy", "hemoglobin",
            ],
            "STUDY PROCEDURES": [
                "procedure", "assessment", "blood sample", "mri",
                "photograph", "rehabilitation", "collection",
            ],
            "STUDY TREATMENT/MEDICATION": [
                "device", "medication", "concomitant", "prohibited",
                "treatment", "implanted", "calibration", "storage",
            ],
            "VISIT SCHEDULE": [
                "visit", "schedule", "window", "late", "missed",
                "early", "phone call",
            ],
            "SAFETY REPORTING": [
                "safety", "adverse event", "sae", "report",
                "malfunction", "severity", "downgrade",
            ],
        }

        scores = {}
        for category, keywords in keyword_map.items():
            score = sum(1 for kw in keywords if kw in text_lower)
            scores[category] = score

        best_cat = max(scores, key=scores.get, default="OTHER")
        if scores.get(best_cat, 0) == 0:
            best_cat = "OTHER"

        total = sum(scores.values()) or 1
        probs = {cat: round(scores.get(cat, 0) / total, 4) for cat in self.categories}
        probs[best_cat] = max(probs[best_cat], 0.5)

        return {
            "category": best_cat,
            "confidence": probs[best_cat],
            "probabilities": probs,
        }


# Global instance for reticulate access
_classifier = None


def get_classifier():
    global _classifier
    if _classifier is None:
        _classifier = DeviationClassifier()
    return _classifier


def classify_deviation(text):
    """Classify a single deviation (called from R)."""
    return get_classifier().classify(text)


def classify_deviations_batch(texts):
    """Classify multiple deviations (called from R)."""
    return get_classifier().classify_batch(list(texts))
