import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

def generate_health_data(n_patients=1000, days_per_patient=90):
    """
    Generate realistic synthetic health data for blood sugar prediction
    """
    np.random.seed(42)
    random.seed(42)
    
    data = []
    
    for patient_id in range(1, n_patients + 1):
        # Patient baseline characteristics
        age = np.random.normal(45, 15)
        age = max(18, min(80, age))
        
        # Diabetes type (1=Type1, 2=Type2, 0=Prediabetic)
        diabetes_type = np.random.choice([0, 1, 2], p=[0.3, 0.1, 0.6])
        
        # Baseline glucose level based on diabetes type
        if diabetes_type == 0:  # Prediabetic
            baseline_glucose = np.random.normal(110, 10)
        elif diabetes_type == 1:  # Type 1
            baseline_glucose = np.random.normal(160, 30)
        else:  # Type 2
            baseline_glucose = np.random.normal(140, 25)
            
        baseline_glucose = max(80, min(300, baseline_glucose))
        
        # Generate daily records
        start_date = datetime(2024, 1, 1)
        
        for day in range(days_per_patient):
            current_date = start_date + timedelta(days=day)
            
            # Daily patterns
            for measurement in range(4):  # 4 measurements per day
                hour = [7, 12, 18, 22][measurement]  # Morning, lunch, dinner, night
                timestamp = current_date.replace(hour=hour)
                
                # Sport intensity (0-10 scale, previous day affects next day glucose)
                sport_intensity = np.random.exponential(2)
                sport_intensity = min(10, sport_intensity)
                
                # Meal carbs (grams)
                if hour in [7, 12, 18]:  # Meal times
                    meal_carbs = np.random.normal(45, 20)
                    meal_carbs = max(0, meal_carbs)
                else:  # Night snack
                    meal_carbs = np.random.exponential(10)
                    
                # Sleep quality (1-10)
                sleep_quality = np.random.normal(7, 1.5)
                sleep_quality = max(1, min(10, sleep_quality))
                
                # Stress level (1-10)
                stress_level = np.random.normal(5, 2)
                stress_level = max(1, min(10, stress_level))
                
                # Medication adherence (0-1)
                if diabetes_type > 0:
                    medication_adherence = np.random.beta(8, 2)  # Most people are adherent
                else:
                    medication_adherence = 0
                
                # Calculate glucose with realistic correlations
                glucose_delta = 0
                
                # Meal impact (immediate)
                glucose_delta += meal_carbs * 1.5
                
                # Sport impact (delayed, negative correlation)
                glucose_delta -= sport_intensity * 8
                
                # Sleep impact
                glucose_delta -= (sleep_quality - 5) * 3
                
                # Stress impact
                glucose_delta += (stress_level - 5) * 4
                
                # Medication impact
                glucose_delta -= medication_adherence * 20
                
                # Time of day effect
                if hour == 7:  # Dawn phenomenon
                    glucose_delta += 15
                elif hour == 22:  # Evening drop
                    glucose_delta -= 10
                
                # Random noise
                glucose_delta += np.random.normal(0, 15)
                
                # Final glucose calculation
                glucose_level = baseline_glucose + glucose_delta
                glucose_level = max(50, min(400, glucose_level))
                glucose_level = round(glucose_level, 1)

                # Risk flag (>180 mg/dL) based on rounded value
                risk_flag = 1 if glucose_level > 180 else 0

                data.append({
                    'patient_id': patient_id,
                    'timestamp': timestamp,
                    'age': round(age, 1),
                    'diabetes_type': diabetes_type,
                    'glucose_level': glucose_level,
                    'sport_intensity': round(sport_intensity, 1),
                    'meal_carbs': round(meal_carbs, 1),
                    'sleep_quality': round(sleep_quality, 1),
                    'stress_level': round(stress_level, 1),
                    'medication_adherence': round(medication_adherence, 2),
                    'risk_flag': risk_flag
                })
    
    df = pd.DataFrame(data)
    return df

if __name__ == "__main__":
    # Generate data
    print("Generating synthetic health data...")
    df = generate_health_data(n_patients=1000, days_per_patient=90)
    
    # Save to CSV
    df.to_csv('health_data.csv', index=False)
    
    print(f"Generated {len(df)} records for {df['patient_id'].nunique()} patients")
    print(f"Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
    print(f"Risk cases: {df['risk_flag'].sum()}/{len(df)} ({df['risk_flag'].mean()*100:.1f}%)")
    print("\nFirst 5 rows:")
    print(df.head())