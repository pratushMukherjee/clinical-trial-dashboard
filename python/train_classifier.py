"""
train_classifier.py -- Train Protocol Deviation text classifier
Model: TF-IDF + Logistic Regression pipeline

Deliberate model choice: With ~100-200 training examples, a TF-IDF + Logistic
Regression pipeline outperforms or matches deep learning while being:
- Interpretable (feature weights show which words drive predictions)
- Fast (trains in seconds, no GPU needed)
- Deployment-friendly (serializes to small pickle file)

Usage: python python/train_classifier.py
"""

import os
import pickle
import pandas as pd
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.pipeline import Pipeline


def main():
    print("=" * 60)
    print("Protocol Deviation Classifier -- Training")
    print("=" * 60)

    # Load deviation data
    dv = pd.read_csv("data/sdtm_dv.csv")
    print(f"\nLoaded {len(dv)} protocol deviation records")
    print(f"Categories: {dv['DVCAT'].nunique()}")
    print(f"\nCategory distribution:")
    print(dv["DVCAT"].value_counts().to_string())

    # Features and labels
    X = dv["DVTERM"].values
    y = dv["DVCAT"].values

    # Train/test split (stratified)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"\nTraining set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")

    # Build pipeline
    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(
            max_features=500,
            ngram_range=(1, 2),  # Unigrams + bigrams
            stop_words="english",
            min_df=1,
            max_df=0.95
        )),
        ("clf", LogisticRegression(
            max_iter=1000,
            C=1.0,
            class_weight="balanced",  # Handle class imbalance
            random_state=42,
            solver="lbfgs"
        ))
    ])

    # Train
    print("\nTraining TF-IDF + Logistic Regression pipeline...")
    pipeline.fit(X_train, y_train)

    # Cross-validation on training set
    cv_scores = cross_val_score(pipeline, X_train, y_train, cv=3, scoring="accuracy")
    print(f"\n3-Fold CV Accuracy: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})")

    # Evaluate on test set
    y_pred = pipeline.predict(X_test)
    accuracy = (y_pred == y_test).mean()
    print(f"\nTest Set Accuracy: {accuracy:.3f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print("Confusion Matrix:")
    labels = sorted(dv["DVCAT"].unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    print(pd.DataFrame(cm, index=labels, columns=labels).to_string())

    # Save model components
    os.makedirs("models", exist_ok=True)

    # Save the full pipeline (includes both vectorizer and classifier)
    with open("models/deviation_pipeline.pkl", "wb") as f:
        pickle.dump(pipeline, f)

    # Also save separately for flexibility
    with open("models/tfidf_vectorizer.pkl", "wb") as f:
        pickle.dump(pipeline.named_steps["tfidf"], f)

    with open("models/deviation_model.pkl", "wb") as f:
        pickle.dump(pipeline.named_steps["clf"], f)

    print("\nModel saved to models/deviation_pipeline.pkl")

    # Show top features per category
    print("\n" + "=" * 60)
    print("Top discriminative features per category:")
    print("=" * 60)
    feature_names = pipeline.named_steps["tfidf"].get_feature_names_out()
    coefs = pipeline.named_steps["clf"].coef_

    for i, label in enumerate(pipeline.named_steps["clf"].classes_):
        top_idx = coefs[i].argsort()[-5:][::-1]
        top_features = [feature_names[j] for j in top_idx]
        print(f"\n{label}:")
        print(f"  {', '.join(top_features)}")

    print("\n" + "=" * 60)
    print("Training complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
