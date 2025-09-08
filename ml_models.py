import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.preprocessing import StandardScaler
import xgboost as xgb
import joblib
import warnings
warnings.filterwarnings('ignore')

class HealthPredictor:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.feature_importance = None
        
    def create_features(self, df):
        """Engineer time-based and rolling features"""
        df = df.copy()
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df = df.sort_values(['patient_id', 'timestamp'])
        
        # Time features
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
        df['is_morning'] = (df['hour'] <= 10).astype(int)
        df['is_evening'] = (df['hour'] >= 18).astype(int)
        
        # Rolling features (previous 24h)
        df['glucose_lag_1'] = df.groupby('patient_id')['glucose_level'].shift(1)
        df['glucose_lag_2'] = df.groupby('patient_id')['glucose_level'].shift(2)
        df['glucose_mean_24h'] = df.groupby('patient_id')['glucose_level'].rolling(window=6, min_periods=1).mean().reset_index(0, drop=True)
        df['glucose_std_24h'] = df.groupby('patient_id')['glucose_level'].rolling(window=6, min_periods=1).std().reset_index(0, drop=True)
        
        # Meal and exercise patterns
        df['carbs_lag_1'] = df.groupby('patient_id')['meal_carbs'].shift(1)
        df['sport_lag_1'] = df.groupby('patient_id')['sport_intensity'].shift(1)
        df['sleep_lag_1'] = df.groupby('patient_id')['sleep_quality'].shift(1)
        
        # Risk indicators
        df['high_carb_meal'] = (df['meal_carbs'] > df['meal_carbs'].quantile(0.8)).astype(int)
        df['low_sleep'] = (df['sleep_quality'] < 6).astype(int)
        df['high_stress'] = (df['stress_level'] > 7).astype(int)
        df['poor_adherence'] = (df['medication_adherence'] < 0.8).astype(int)
        
        # Patient-level aggregations
        patient_stats = df.groupby('patient_id').agg({
            'glucose_level': ['mean', 'std']
        }).round(2)
        patient_stats.columns = ['patient_glucose_mean', 'patient_glucose_std']
        df = df.merge(patient_stats, left_on='patient_id', right_index=True)
        
        # Fill NaN values
        df = df.fillna(df.median(numeric_only=True))
        
        return df
    
    def prepare_data(self, df, target_col='glucose_level'):
        """Prepare features and target for modeling"""
        df_features = self.create_features(df)
        
        # Feature columns
        feature_cols = [
            'age', 'diabetes_type', 'sport_intensity', 'meal_carbs', 
            'sleep_quality', 'stress_level', 'medication_adherence',
            'hour', 'day_of_week', 'is_weekend', 'is_morning', 'is_evening',
            'glucose_lag_1', 'glucose_lag_2', 'glucose_mean_24h', 'glucose_std_24h',
            'carbs_lag_1', 'sport_lag_1', 'sleep_lag_1',
            'high_carb_meal', 'low_sleep', 'high_stress', 'poor_adherence',
            'patient_glucose_mean', 'patient_glucose_std'
        ]
        
        # Remove rows with NaN in target or key features
        df_clean = df_features.dropna(subset=[target_col, 'glucose_lag_1'])
        
        X = df_clean[feature_cols]
        y = df_clean[target_col]
        
        return X, y, df_clean
    
    def train_model(self, X, y, test_size=0.2, random_state=42):
        """Train XGBoost model with validation"""
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=X['diabetes_type']
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # XGBoost model
        self.model = xgb.XGBRegressor(
            n_estimators=200,
            max_depth=6,
            learning_rate=0.1,
            subsample=0.8,
            colsample_bytree=0.8,
            random_state=random_state,
            n_jobs=-1
        )
        
        # Train model
        self.model.fit(X_train_scaled, y_train)
        
        # Predictions
        y_pred_train = self.model.predict(X_train_scaled)
        y_pred_test = self.model.predict(X_test_scaled)
        
        # Metrics
        train_metrics = {
            'rmse': np.sqrt(mean_squared_error(y_train, y_pred_train)),
            'mae': mean_absolute_error(y_train, y_pred_train),
            'r2': r2_score(y_train, y_pred_train)
        }
        
        test_metrics = {
            'rmse': np.sqrt(mean_squared_error(y_test, y_pred_test)),
            'mae': mean_absolute_error(y_test, y_pred_test),
            'r2': r2_score(y_test, y_pred_test)
        }
        
        # Feature importance
        self.feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': self.model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        # Cross-validation
        cv_scores = cross_val_score(self.model, X_train_scaled, y_train, cv=5, scoring='neg_mean_squared_error')
        cv_rmse = np.sqrt(-cv_scores.mean())
        
        return {
            'train_metrics': train_metrics,
            'test_metrics': test_metrics,
            'cv_rmse': cv_rmse,
            'feature_importance': self.feature_importance
        }
    
    def predict(self, X):
        """Make predictions on new data"""
        if self.model is None:
            raise ValueError("Model not trained yet. Call train_model() first.")
        
        X_scaled = self.scaler.transform(X)
        predictions = self.model.predict(X_scaled)
        return predictions
    
    def predict_risk(self, X, threshold=180):
        """Predict glucose levels and risk flags"""
        predictions = self.predict(X)
        risk_flags = (predictions > threshold).astype(int)
        return predictions, risk_flags
    
    def save_model(self, filepath='health_model.pkl'):
        """Save trained model and scaler"""
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_importance': self.feature_importance
        }
        joblib.dump(model_data, filepath)
        
    def load_model(self, filepath='health_model.pkl'):
        """Load trained model and scaler"""
        model_data = joblib.load(filepath)
        self.model = model_data['model']
        self.scaler = model_data['scaler']
        self.feature_importance = model_data['feature_importance']

def train_and_evaluate_model(data_path='health_data.csv'):
    """Main training pipeline"""
    # Load data
    df = pd.read_csv(data_path)
    print(f"Loaded {len(df)} records for {df['patient_id'].nunique()} patients")
    
    # Initialize predictor
    predictor = HealthPredictor()
    
    # Prepare data
    X, y, df_clean = predictor.prepare_data(df)
    print(f"Prepared features: {X.shape}")
    
    # Train model
    results = predictor.train_model(X, y)
    
    # Print results
    print("\n=== MODEL PERFORMANCE ===")
    print(f"Train RMSE: {results['train_metrics']['rmse']:.2f}")
    print(f"Test RMSE: {results['test_metrics']['rmse']:.2f}")
    print(f"Test R²: {results['test_metrics']['r2']:.3f}")
    print(f"CV RMSE: {results['cv_rmse']:.2f}")
    
    print("\n=== TOP FEATURES ===")
    print(results['feature_importance'].head(10))
    
    # Save model
    predictor.save_model()
    print("\nModel saved as 'health_model.pkl'")
    
    return predictor, results

if __name__ == "__main__":
    predictor, results = train_and_evaluate_model()