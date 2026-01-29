import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import tempfile
import os

from data_generator import generate_health_data
from ml_models import HealthPredictor

class TestDataGeneration:
    def test_generate_health_data_shape(self):
        """Test data generation returns correct shape"""
        df = generate_health_data(n_patients=10, days_per_patient=5)
        
        expected_rows = 10 * 5 * 4  # patients * days * measurements_per_day
        assert len(df) == expected_rows
        assert df['patient_id'].nunique() == 10
        
    def test_data_columns(self):
        """Test generated data has required columns"""
        df = generate_health_data(n_patients=5, days_per_patient=3)
        
        required_cols = [
            'patient_id', 'timestamp', 'age', 'diabetes_type',
            'glucose_level', 'sport_intensity', 'meal_carbs',
            'sleep_quality', 'stress_level', 'medication_adherence', 'risk_flag'
        ]
        
        for col in required_cols:
            assert col in df.columns
    
    def test_data_ranges(self):
        """Test data values are within expected ranges"""
        df = generate_health_data(n_patients=20, days_per_patient=7)
        
        # Test ranges
        assert df['age'].min() >= 18
        assert df['age'].max() <= 80
        assert df['diabetes_type'].isin([0, 1, 2]).all()
        assert df['glucose_level'].min() >= 50
        assert df['glucose_level'].max() <= 400
        assert df['sport_intensity'].min() >= 0
        assert df['sport_intensity'].max() <= 10
        assert df['sleep_quality'].min() >= 1
        assert df['sleep_quality'].max() <= 10
        assert df['stress_level'].min() >= 1
        assert df['stress_level'].max() <= 10
        assert df['medication_adherence'].min() >= 0
        assert df['medication_adherence'].max() <= 1
        assert df['risk_flag'].isin([0, 1]).all()
    
    def test_risk_flag_logic(self):
        """Test risk flag is correctly calculated"""
        df = generate_health_data(n_patients=50, days_per_patient=10)
        
        # Risk flag should be 1 when glucose > 180
        high_glucose = df[df['glucose_level'] > 180]
        assert (high_glucose['risk_flag'] == 1).all()
        
        # Risk flag should be 0 when glucose <= 180
        normal_glucose = df[df['glucose_level'] <= 180]
        assert (normal_glucose['risk_flag'] == 0).all()

class TestHealthPredictor:
    @pytest.fixture
    def sample_data(self):
        """Generate sample data for testing"""
        return generate_health_data(n_patients=50, days_per_patient=14)
    
    @pytest.fixture
    def predictor(self):
        """Create HealthPredictor instance"""
        return HealthPredictor()
    
    def test_create_features(self, predictor, sample_data):
        """Test feature engineering"""
        df_features = predictor.create_features(sample_data)
        
        # Check new features are created
        expected_features = [
            'hour', 'day_of_week', 'is_weekend', 'is_morning', 'is_evening',
            'glucose_lag_1', 'glucose_lag_2', 'glucose_mean_24h',
            'high_carb_meal', 'low_sleep', 'high_stress', 'poor_adherence'
        ]
        
        for feature in expected_features:
            assert feature in df_features.columns
    
    def test_prepare_data(self, predictor, sample_data):
        """Test data preparation for modeling"""
        X, y, df_clean = predictor.prepare_data(sample_data)
        
        # Check shapes
        assert len(X) == len(y)
        assert len(X) > 0
        
        # Check no NaN in target
        assert not y.isna().any()
        
        # Check feature types
        assert isinstance(X, pd.DataFrame)
        assert isinstance(y, pd.Series)
    
    def test_model_training(self, predictor, sample_data):
        """Test model training process"""
        X, y, _ = predictor.prepare_data(sample_data)
        
        # Train model
        results = predictor.train_model(X, y)
        
        # Check model exists
        assert predictor.model is not None
        assert predictor.scaler is not None
        
        # Check results structure
        assert 'train_metrics' in results
        assert 'test_metrics' in results
        assert 'cv_rmse' in results
        assert 'feature_importance' in results
        
        # Check metrics are reasonable
        assert results['test_metrics']['rmse'] > 0
        assert results['test_metrics']['r2'] <= 1
    
    def test_predictions(self, predictor, sample_data):
        """Test prediction functionality"""
        X, y, _ = predictor.prepare_data(sample_data)
        
        # Train model
        predictor.train_model(X, y)
        
        # Make predictions
        predictions = predictor.predict(X[:10])
        
        # Check prediction shape and type
        assert len(predictions) == 10
        assert isinstance(predictions, np.ndarray)
        assert all(pred > 0 for pred in predictions)  # Glucose should be positive
    
    def test_risk_prediction(self, predictor, sample_data):
        """Test risk prediction functionality"""
        X, y, _ = predictor.prepare_data(sample_data)
        
        # Train model
        predictor.train_model(X, y)
        
        # Make risk predictions
        predictions, risk_flags = predictor.predict_risk(X[:10])
        
        # Check shapes
        assert len(predictions) == len(risk_flags) == 10
        assert all(flag in [0, 1] for flag in risk_flags)
        
        # Check logic: high glucose should have risk flag
        for pred, risk in zip(predictions, risk_flags):
            if pred > 180:
                assert risk == 1
            else:
                assert risk == 0
    
    def test_model_save_load(self, predictor, sample_data):
        """Test model saving and loading"""
        X, y, _ = predictor.prepare_data(sample_data)
        
        # Train model
        predictor.train_model(X, y)
        
        # Save model
        with tempfile.NamedTemporaryFile(suffix='.pkl', delete=False) as tmp:
            predictor.save_model(tmp.name)
            
            # Create new predictor and load model
            new_predictor = HealthPredictor()
            new_predictor.load_model(tmp.name)
            
            # Test predictions are the same
            original_pred = predictor.predict(X[:5])
            loaded_pred = new_predictor.predict(X[:5])
            
            np.testing.assert_array_almost_equal(original_pred, loaded_pred, decimal=5)
            
            # Clean up
            os.unlink(tmp.name)

class TestDataQuality:
    def test_no_duplicate_timestamps_per_patient(self):
        """Test no duplicate timestamps per patient"""
        df = generate_health_data(n_patients=20, days_per_patient=10)
        
        duplicates = df.groupby(['patient_id', 'timestamp']).size().max()
        assert duplicates == 1, "Found duplicate timestamps for same patient"
    
    def test_realistic_correlations(self):
        """Test data has realistic correlations"""
        df = generate_health_data(n_patients=100, days_per_patient=30)
        
        # Sport should negatively correlate with glucose
        sport_glucose_corr = df['sport_intensity'].corr(df['glucose_level'])
        assert sport_glucose_corr < 0, "Sport should negatively correlate with glucose"
        
        # Meal carbs should positively correlate with glucose
        carbs_glucose_corr = df['meal_carbs'].corr(df['glucose_level'])
        assert carbs_glucose_corr > 0, "Carbs should positively correlate with glucose"
    
    def test_diabetes_type_glucose_differences(self):
        """Test different diabetes types have different glucose patterns"""
        df = generate_health_data(n_patients=200, days_per_patient=20)
        
        glucose_by_type = df.groupby('diabetes_type')['glucose_level'].mean()
        
        # Type 1 and Type 2 should have higher glucose than prediabetic
        assert glucose_by_type[1] > glucose_by_type[0]  # Type 1 > Prediabetic
        assert glucose_by_type[2] > glucose_by_type[0]  # Type 2 > Prediabetic

if __name__ == "__main__":
    pytest.main([__file__, "-v"])