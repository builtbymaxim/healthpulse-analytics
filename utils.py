import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import logging
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def setup_logging():
    """Configure logging for the application"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('healthpulse.log'),
            logging.StreamHandler()
        ]
    )

def validate_glucose_reading(glucose_level):
    """Validate glucose reading is within realistic range"""
    if not isinstance(glucose_level, (int, float)):
        return False
    return 40 <= glucose_level <= 600  # Extreme but possible range

def calculate_risk_score(glucose_level, diabetes_type):
    """Calculate risk score based on glucose level and diabetes type"""
    base_risk = 0
    
    if glucose_level > 180:
        base_risk = 0.8
    elif glucose_level > 140:
        base_risk = 0.4
    elif glucose_level > 100:
        base_risk = 0.1
    
    # Adjust for diabetes type
    if diabetes_type == 1:  # Type 1
        base_risk *= 1.3
    elif diabetes_type == 2:  # Type 2
        base_risk *= 1.1
    
    return min(1.0, base_risk)

def get_lifestyle_recommendations(glucose_level, sport_intensity, meal_carbs, sleep_quality, stress_level):
    """Generate lifestyle recommendations based on current metrics"""
    recommendations = []
    
    if glucose_level > 180:
        recommendations.append("🚨 High glucose detected. Consider consulting healthcare provider.")
    
    if sport_intensity < 3:
        recommendations.append("🏃 Increase physical activity to help regulate glucose levels.")
    
    if meal_carbs > 60:
        recommendations.append("🍽️ Consider reducing carbohydrate intake in next meal.")
    
    if sleep_quality < 6:
        recommendations.append("😴 Improve sleep quality - aim for 7-9 hours of quality sleep.")
    
    if stress_level > 7:
        recommendations.append("🧘 Practice stress management techniques like meditation or deep breathing.")
    
    if not recommendations:
        recommendations.append("✅ Current metrics look good! Keep up the healthy lifestyle.")
    
    return recommendations

def format_glucose_display(glucose_level):
    """Format glucose level for display with appropriate units and color coding"""
    if glucose_level > 180:
        return f"🔴 {glucose_level:.1f} mg/dL (High Risk)"
    elif glucose_level > 140:
        return f"🟡 {glucose_level:.1f} mg/dL (Elevated)"
    else:
        return f"🟢 {glucose_level:.1f} mg/dL (Normal)"

def calculate_time_in_range(glucose_readings, target_min=70, target_max=180):
    """Calculate percentage of time glucose readings are in target range"""
    in_range = [(target_min <= reading <= target_max) for reading in glucose_readings]
    return (sum(in_range) / len(in_range)) * 100 if glucose_readings else 0

def generate_patient_summary(patient_data):
    """Generate comprehensive patient summary statistics"""
    summary = {
        'patient_id': patient_data['patient_id'].iloc[0],
        'age': patient_data['age'].iloc[0],
        'diabetes_type': patient_data['diabetes_type'].iloc[0],
        'total_measurements': len(patient_data),
        'avg_glucose': patient_data['glucose_level'].mean(),
        'glucose_std': patient_data['glucose_level'].std(),
        'min_glucose': patient_data['glucose_level'].min(),
        'max_glucose': patient_data['glucose_level'].max(),
        'risk_episodes': patient_data['risk_flag'].sum(),
        'risk_percentage': (patient_data['risk_flag'].sum() / len(patient_data)) * 100,
        'time_in_range': calculate_time_in_range(patient_data['glucose_level'].tolist()),
        'avg_sport_intensity': patient_data['sport_intensity'].mean(),
        'avg_meal_carbs': patient_data['meal_carbs'].mean(),
        'avg_sleep_quality': patient_data['sleep_quality'].mean(),
        'avg_stress_level': patient_data['stress_level'].mean(),
        'medication_adherence': patient_data['medication_adherence'].mean()
    }
    
    return summary

def export_patient_report(patient_data, filepath=None, format="json"):
    """Export a detailed patient report.

    Parameters
    ----------
    patient_data : pd.DataFrame
        Data for a single patient.
    filepath : str, optional
        Destination path for the exported report.
    format : str, default "json"
        One of ``{"json", "pdf", "html"}``.
    """

    summary = generate_patient_summary(patient_data)

    recent_data = patient_data.tail(20)
    summary["recent_trend"] = {
        "avg_glucose_last_20": recent_data["glucose_level"].mean(),
        "risk_episodes_last_20": recent_data["risk_flag"].sum(),
        "glucose_trend": "increasing"
        if recent_data["glucose_level"].iloc[-5:].mean()
        > recent_data["glucose_level"].iloc[:5].mean()
        else "decreasing",
    }

    last_reading = patient_data.iloc[-1]
    summary["recommendations"] = get_lifestyle_recommendations(
        last_reading["glucose_level"],
        last_reading["sport_intensity"],
        last_reading["meal_carbs"],
        last_reading["sleep_quality"],
        last_reading["stress_level"],
    )

    format = format.lower()
    if filepath:
        if format == "json":
            with open(filepath, "w") as f:
                json.dump(summary, f, indent=2, default=str)
        elif format == "pdf":
            try:
                from fpdf import FPDF
            except ImportError as exc:  # pragma: no cover - optional dependency
                raise ImportError("fpdf is required for PDF export") from exc
            pdf = FPDF()
            pdf.add_page()
            pdf.set_font("Arial", size=12)
            for key, value in summary.items():
                pdf.multi_cell(0, 10, f"{key}: {value}")
            pdf.output(filepath)
        elif format == "html":
            html = "<html><body><h1>Patient Report</h1><pre>" + json.dumps(
                summary, indent=2, default=str
            ) + "</pre></body></html>"
            with open(filepath, "w") as f:
                f.write(html)
        else:
            raise ValueError("Unsupported format. Choose from 'json', 'pdf', or 'html'.")
        logger.info(f"Patient report exported to {filepath}")

    return summary

def validate_model_inputs(age, diabetes_type, sport_intensity, meal_carbs, sleep_quality, stress_level, medication_adherence):
    """Validate all model input parameters"""
    errors = []
    
    if not (18 <= age <= 100):
        errors.append("Age must be between 18 and 100")
    
    if diabetes_type not in [0, 1, 2]:
        errors.append("Diabetes type must be 0, 1, or 2")
    
    if not (0 <= sport_intensity <= 10):
        errors.append("Sport intensity must be between 0 and 10")
    
    if not (0 <= meal_carbs <= 200):
        errors.append("Meal carbs must be between 0 and 200 grams")
    
    if not (1 <= sleep_quality <= 10):
        errors.append("Sleep quality must be between 1 and 10")
    
    if not (1 <= stress_level <= 10):
        errors.append("Stress level must be between 1 and 10")
    
    if not (0 <= medication_adherence <= 1):
        errors.append("Medication adherence must be between 0 and 1")
    
    return errors

def get_diabetes_type_info(diabetes_type):
    """Get information about diabetes type"""
    info = {
        0: {
            'name': 'Prediabetic',
            'description': 'Blood sugar levels are higher than normal but not high enough to be diagnosed as diabetes.',
            'target_glucose': '70-140 mg/dL',
            'risk_level': 'Low to Moderate'
        },
        1: {
            'name': 'Type 1 Diabetes',
            'description': 'An autoimmune condition where the pancreas produces little or no insulin.',
            'target_glucose': '80-180 mg/dL',
            'risk_level': 'High'
        },
        2: {
            'name': 'Type 2 Diabetes',
            'description': 'A condition where the body becomes resistant to insulin or doesn\'t make enough insulin.',
            'target_glucose': '80-180 mg/dL',
            'risk_level': 'Moderate to High'
        }
    }
    
    return info.get(diabetes_type, {'name': 'Unknown', 'description': 'Unknown diabetes type'})

def calculate_daily_stats(patient_data):
    """Calculate daily statistics for a patient"""
    patient_data['date'] = pd.to_datetime(patient_data['timestamp']).dt.date
    
    daily_stats = patient_data.groupby('date').agg({
        'glucose_level': ['mean', 'min', 'max', 'std'],
        'sport_intensity': 'mean',
        'meal_carbs': 'sum',
        'sleep_quality': 'mean',
        'stress_level': 'mean',
        'risk_flag': 'sum'
    }).round(2)
    
    # Flatten column names
    daily_stats.columns = [f"{col[1]}_{col[0]}" if col[1] else col[0] for col in daily_stats.columns]
    daily_stats = daily_stats.reset_index()
    
    return daily_stats

# Health check function for deployment
def health_check():
    """Simple health check for the application"""
    try:
        # Check if required modules can be imported
        import pandas
        import numpy
        import sklearn
        import xgboost
        import streamlit
        
        return {"status": "healthy", "timestamp": datetime.now().isoformat()}
    except ImportError as e:
        return {"status": "unhealthy", "error": str(e), "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    # Run health check
    result = health_check()
    print(json.dumps(result, indent=2))
