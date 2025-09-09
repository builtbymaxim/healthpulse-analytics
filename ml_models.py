"""Machine learning models for HealthPulse Analytics.

The module provides the :class:`HealthPredictor` class used throughout the
application. It features optional hyper-parameter tuning via scikit-learn's
``GridSearchCV`` and fixes previous issues where the file contained leftover
shell prompts that broke imports.
"""

from __future__ import annotations

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GridSearchCV, cross_val_score, train_test_split
from sklearn.preprocessing import StandardScaler
import xgboost as xgb


class HealthPredictor:
    """Predict future glucose levels using gradient boosting."""

    def __init__(self) -> None:
        self.model: xgb.XGBRegressor | None = None
        self.scaler = StandardScaler()
        self.feature_importance: pd.DataFrame | None = None

    # ------------------------------------------------------------------
    # Feature engineering
    # ------------------------------------------------------------------
    def create_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Engineer time-based and rolling features."""

        df = df.copy()
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df = df.sort_values(['patient_id', 'timestamp'])

        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
        df['is_morning'] = (df['hour'] <= 10).astype(int)
        df['is_evening'] = (df['hour'] >= 18).astype(int)

        df['glucose_lag_1'] = df.groupby('patient_id')['glucose_level'].shift(1)
        df['glucose_lag_2'] = df.groupby('patient_id')['glucose_level'].shift(2)
        df['glucose_mean_24h'] = (
            df.groupby('patient_id')['glucose_level']
            .rolling(window=6, min_periods=1)
            .mean()
            .reset_index(0, drop=True)
        )
        df['glucose_std_24h'] = (
            df.groupby('patient_id')['glucose_level']
            .rolling(window=6, min_periods=1)
            .std()
            .reset_index(0, drop=True)
        )

        df['carbs_lag_1'] = df.groupby('patient_id')['meal_carbs'].shift(1)
        df['sport_lag_1'] = df.groupby('patient_id')['sport_intensity'].shift(1)
        df['sleep_lag_1'] = df.groupby('patient_id')['sleep_quality'].shift(1)

        df['high_carb_meal'] = (df['meal_carbs'] > df['meal_carbs'].quantile(0.8)).astype(int)
        df['low_sleep'] = (df['sleep_quality'] < 6).astype(int)
        df['high_stress'] = (df['stress_level'] > 7).astype(int)
        df['poor_adherence'] = (df['medication_adherence'] < 0.8).astype(int)

        patient_stats = df.groupby('patient_id').agg({'glucose_level': ['mean', 'std']}).round(2)
        patient_stats.columns = ['patient_glucose_mean', 'patient_glucose_std']
        df = df.merge(patient_stats, left_on='patient_id', right_index=True)

        df = df.fillna(df.median(numeric_only=True))
        return df

    # ------------------------------------------------------------------
    # Data preparation
    # ------------------------------------------------------------------
    def prepare_data(self, df: pd.DataFrame, target_col: str = 'glucose_level'):
        """Prepare features and target for modelling."""

        df_features = self.create_features(df)
        feature_cols = [
            'age', 'diabetes_type', 'sport_intensity', 'meal_carbs',
            'sleep_quality', 'stress_level', 'medication_adherence',
            'hour', 'day_of_week', 'is_weekend', 'is_morning', 'is_evening',
            'glucose_lag_1', 'glucose_lag_2', 'glucose_mean_24h', 'glucose_std_24h',
            'carbs_lag_1', 'sport_lag_1', 'sleep_lag_1',
            'high_carb_meal', 'low_sleep', 'high_stress', 'poor_adherence',
            'patient_glucose_mean', 'patient_glucose_std'
        ]

        df_clean = df_features.dropna(subset=[target_col, 'glucose_lag_1'])
        X = df_clean[feature_cols]
        y = df_clean[target_col]
        return X, y, df_clean

    # ------------------------------------------------------------------
    # Model training
    # ------------------------------------------------------------------
    def train_model(
        self,
        X: pd.DataFrame,
        y: pd.Series,
        test_size: float = 0.2,
        random_state: int = 42,
        tune_hyperparameters: bool = False,
    ):
        """Train XGBoost model with optional hyper-parameter tuning."""

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=X['diabetes_type']
        )

        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        if tune_hyperparameters:
            param_grid = {
                'n_estimators': [100, 200],
                'max_depth': [4, 6],
                'learning_rate': [0.05, 0.1],
            }
            base_model = xgb.XGBRegressor(
                subsample=0.8,
                colsample_bytree=0.8,
                random_state=random_state,
                n_jobs=-1,
            )
            grid = GridSearchCV(base_model, param_grid, cv=3, scoring='neg_mean_squared_error')
            grid.fit(X_train_scaled, y_train)
            self.model = grid.best_estimator_
        else:
            self.model = xgb.XGBRegressor(
                n_estimators=200,
                max_depth=6,
                learning_rate=0.1,
                subsample=0.8,
                colsample_bytree=0.8,
                random_state=random_state,
                n_jobs=-1,
            )
            self.model.fit(X_train_scaled, y_train)

        y_pred_train = self.model.predict(X_train_scaled)
        y_pred_test = self.model.predict(X_test_scaled)

        train_metrics = {
            'rmse': float(np.sqrt(mean_squared_error(y_train, y_pred_train))),
            'mae': float(mean_absolute_error(y_train, y_pred_train)),
            'r2': float(r2_score(y_train, y_pred_train)),
        }
        test_metrics = {
            'rmse': float(np.sqrt(mean_squared_error(y_test, y_pred_test))),
            'mae': float(mean_absolute_error(y_test, y_pred_test)),
            'r2': float(r2_score(y_test, y_pred_test)),
        }

        self.feature_importance = (
            pd.DataFrame({'feature': X.columns, 'importance': self.model.feature_importances_})
            .sort_values('importance', ascending=False)
        )

        cv_scores = cross_val_score(self.model, X_train_scaled, y_train, cv=5, scoring='neg_mean_squared_error')
        cv_rmse = float(np.sqrt(-cv_scores.mean()))

        return {
            'train_metrics': train_metrics,
            'test_metrics': test_metrics,
            'cv_rmse': cv_rmse,
            'feature_importance': self.feature_importance,
        }

    # ------------------------------------------------------------------
    # Prediction helpers
    # ------------------------------------------------------------------
    def predict(self, X: pd.DataFrame) -> np.ndarray:
        if self.model is None:
            raise ValueError("Model not trained yet. Call train_model() first.")
        X_scaled = self.scaler.transform(X)
        return self.model.predict(X_scaled)

    def predict_risk(self, X: pd.DataFrame, threshold: float = 180):
        predictions = self.predict(X)
        risk_flags = (predictions > threshold).astype(int)
        return predictions, risk_flags

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------
    def save_model(self, filepath: str = 'health_model.pkl') -> None:
        joblib.dump({'model': self.model, 'scaler': self.scaler, 'feature_importance': self.feature_importance}, filepath)

    def load_model(self, filepath: str = 'health_model.pkl') -> None:
        data = joblib.load(filepath)
        self.model = data['model']
        self.scaler = data['scaler']
        self.feature_importance = data['feature_importance']


def train_and_evaluate_model(data_path: str = 'health_data.csv') -> None:
    """Standalone training script."""

    df = pd.read_csv(data_path)
    predictor = HealthPredictor()
    X, y, _ = predictor.prepare_data(df)
    results = predictor.train_model(X, y)

    print("=== MODEL PERFORMANCE ===")
    print(f"Train RMSE: {results['train_metrics']['rmse']:.2f}")
    print(f"Test RMSE: {results['test_metrics']['rmse']:.2f}")
    print(f"CV RMSE: {results['cv_rmse']:.2f}")


if __name__ == "__main__":
    train_and_evaluate_model()

