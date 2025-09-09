# HealthPulse Analytics

**AI-Powered Health Intelligence & Glucose Prediction Dashboard**

[![Python](https://img.shields.io/badge/python-3.9%2B-blue.svg)](https://www.python.org/downloads/)
[![Streamlit](https://img.shields.io/badge/streamlit-1.28.0-red.svg)](https://streamlit.io/)
[![XGBoost](https://img.shields.io/badge/xgboost-2.0.0-orange.svg)](https://xgboost.readthedocs.io/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A comprehensive health analytics platform featuring AI-powered glucose prediction, interactive dashboards, and clinical report generation. Built with modern UI/UX design including light/dark mode themes.

## Features

- **AI Glucose Prediction**: XGBoost model with 92.5% accuracy (R² = 0.925)
- **Interactive Dashboard**: Modern Streamlit interface with premium styling
- **Theme System**: Automatic light/dark mode with iOS-style toggle
- **Advanced Analytics**: Correlation analysis, risk assessment, feature importance
- **Patient Management**: Individual patient tracking and analysis
- **Report Generation**: Professional clinical reports with download capability (JSON, HTML, PDF)
- **Risk Assessment**: Automated high-risk patient identification
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Optimized Data Generation**: Vectorised synthetic data creation for faster simulations
- **Model Tuning**: Optional hyperparameter grid search for XGBoost

## Quick Start

### Prerequisites
- Python 3.9 or higher
- pip package manager

### Installation

```bash
# Clone the repository
git clone https://github.com/builtbymaxim/healthpulse-analytics.git
cd healthpulse-analytics

# Install dependencies
pip install -r requirements.txt

# Generate synthetic data and train model
python data_generator.py
python ml_models.py

# Launch the dashboard
streamlit run healthpulse_app.py
```

### Docker Setup

```bash
# Build and run with Docker
docker build -t healthpulse .
docker run -p 8501:8501 healthpulse

# Access at http://localhost:8501
```

## Dashboard Pages

### 1. Overview
- **KPI Cards**: Patient count, demographics, risk metrics
- **Diabetes Distribution**: Patient type breakdown with interactive charts
- **Glucose Trends**: Time-series analysis with confidence intervals
- **Risk Alerts**: Recent high-glucose episodes

### 2. Analytics
- **Correlation Matrix**: Feature relationships and dependencies
- **Risk Analysis**: Normal vs high-risk patient distributions
- **Feature Importance**: XGBoost model explainability

### 3. Prediction
- **Interactive Interface**: Real-time glucose level prediction
- **Risk Assessment**: Immediate risk classification
- **Lifestyle Recommendations**: Personalized health suggestions

### 4. Patients
- **Individual Analysis**: Patient-specific metrics and trends
- **Historical Data**: Glucose patterns over time
- **Clinical Summary**: Key health indicators

### 5. Reports
- **Patient Reports**: Professional clinical documents (HTML/Text)
- **Analytics Summaries**: System-wide health statistics
- **Export Functionality**: Download reports for external use

## Technology Stack

### Backend
- **Python 3.9+**: Core programming language
- **XGBoost**: Machine learning model for glucose prediction
- **scikit-learn**: Data preprocessing and model evaluation
- **Pandas/NumPy**: Data manipulation and analysis

### Frontend
- **Streamlit**: Web application framework
- **Plotly**: Interactive data visualizations
- **CSS3**: Custom styling and animations
- **Font Awesome**: Professional iconography

### Data & ML
- **Synthetic Data**: 360K+ realistic health measurements
- **Feature Engineering**: 25+ derived features for prediction
- **Cross-Validation**: 5-fold CV for model reliability
- **Performance**: RMSE: 14.15 mg/dL, R²: 0.925

## Model Performance

```
Training Metrics:
├── RMSE: 13.64 mg/dL
├── R²: 0.945
└── MAE: 10.12 mg/dL

Test Metrics:
├── RMSE: 14.15 mg/dL  
├── R²: 0.925
└── Cross-Val RMSE: 14.14 mg/dL

Top Features:
├── high_carb_meal (24.6%)
├── meal_carbs (20.2%)
├── hour (14.2%)
├── glucose_mean_24h (9.7%)
└── is_evening (8.2%)
```

## Data Sources & Compatibility

### Current Implementation: Synthetic Data
The project currently uses **completely synthetic health data** for safe development and demonstration:

#### Generated Dataset
- **1000 patients** with diverse demographics
- **90 days** of continuous monitoring per patient
- **4 measurements daily** (360K+ total data points)
- **Realistic correlations** between lifestyle and health metrics

#### Synthetic Health Metrics
- **Glucose levels**: 50-400 mg/dL with realistic patterns
- **Physical activity**: Exercise intensity (0-10 scale)
- **Nutrition**: Meal carbohydrate content (0-100g)
- **Sleep quality**: Subjective rating (1-10)
- **Stress levels**: Self-reported stress (1-10)
- **Medication adherence**: Treatment compliance (0-1)

#### Diabetes Distribution
- **Prediabetic**: 30% of patients
- **Type 1 Diabetes**: 10% of patients  
- **Type 2 Diabetes**: 60% of patients

### Compatible Real-World Data Sources

#### 1. Continuous Glucose Monitor (CGM) Data
- **Dexcom, FreeStyle Libre, Medtronic** CGM exports
- **Format**: CSV/JSON with timestamp + glucose readings
- **Integration**: Combine with lifestyle tracking apps

#### 2. Clinical Research Datasets
- **Anonymized diabetes clinical trial data**
- **Hospital glucose monitoring records**
- **Research institution datasets** (with proper permissions)
- **Public health databases** (CDC, WHO health surveys)

#### 3. Personal Health Apps
- **MyFitnessPal** + glucose meter exports
- **Apple Health/Google Fit** activity data
- **Diabetes management apps** (MySugr, Glucose Buddy)
- **Manual logbook digitization**

#### 4. Wearable Device Integration
- **Apple Watch/Fitbit** activity + manual glucose
- **Sleep tracking** + glucose correlation analysis
- **Heart rate variability** + stress metrics
- **Continuous monitoring devices**

### Data Format Requirements

#### Minimum Required Columns
```python
required_columns = [
    'patient_id',      # Unique identifier (anonymized)
    'timestamp',       # Date/time of measurement
    'glucose_level'    # Blood glucose reading (mg/dL)
]
```

#### Optional Enhancement Columns
```python
optional_columns = [
    'age',                    # Patient age
    'diabetes_type',          # 0=Prediabetic, 1=Type1, 2=Type2
    'medication_adherence',   # 0-1 compliance rate
    'meal_carbs',            # Carbohydrate intake (grams)
    'sport_intensity',       # Exercise level (0-10)
    'sleep_quality',         # Sleep rating (1-10)
    'stress_level',          # Stress level (1-10)
    'weight',                # Body weight (kg)
    'blood_pressure_sys',    # Systolic BP
    'blood_pressure_dia'     # Diastolic BP
]
```

### Data Adaptation Guide

#### For Custom Datasets
1. **Column Mapping**: Rename columns to match expected format
2. **Unit Conversion**: Ensure glucose is in mg/dL (multiply mmol/L by 18.02)
3. **Missing Data**: Handle gaps with interpolation or forward-fill
4. **Feature Engineering**: Generate derived features (time-based, rolling averages)

#### Example Data Preprocessing
```python
def adapt_external_data(df):
    """Adapt external data to HealthPulse format"""
    
    # Standardize column names
    column_mapping = {
        'glucose': 'glucose_level',
        'datetime': 'timestamp',
        'subject_id': 'patient_id'
    }
    df = df.rename(columns=column_mapping)
    
    # Convert units if needed (mmol/L to mg/dL)
    if df['glucose_level'].max() < 30:  # Likely mmol/L
        df['glucose_level'] *= 18.02
    
    # Handle missing values
    df['glucose_level'] = df['glucose_level'].fillna(method='ffill')
    
    # Generate risk flags
    df['risk_flag'] = (df['glucose_level'] > 180).astype(int)
    
    # Add default values for missing lifestyle data
    if 'sport_intensity' not in df.columns:
        df['sport_intensity'] = 5.0  # Default moderate activity
    
    return df
```

### Privacy & Compliance

#### For Real Data Use
- **HIPAA Compliance**: Proper de-identification required
- **IRB Approval**: For research use of patient data
- **Data Sharing Agreements**: With healthcare institutions
- **Local Processing**: No cloud upload of PHI
- **Anonymization**: Remove all personal identifiers

#### Recommended Workflow
1. **Start with synthetic data** (current setup)
2. **Validate with anonymized research datasets**
3. **Partner with institutions** for clinical validation
4. **Implement proper data governance**
5. **Never use identifiable patient data** without protocols

### Model Retraining

#### For New Data Sources
```python
# Retrain model with your data
python data_generator.py --input your_data.csv --preprocess
python ml_models.py --retrain --data processed_data.csv
```

#### Performance Considerations
- **Model Validation**: Test on holdout set from your data
- **Feature Importance**: May differ from synthetic patterns
- **Cross-Validation**: Ensure model generalizes to your population
- **Clinical Validation**: Compare predictions with expert assessments

## Project Structure

```
healthpulse-analytics/
├── healthpulse_app.py        # Main Streamlit dashboard
├── ml_models.py              # XGBoost model and training
├── data_generator.py         # Synthetic health data creation
├── utils.py                  # Helper functions and utilities
├── requirements.txt          # Python dependencies
├── Dockerfile               # Container configuration
├── README.md                # Project documentation
├── test_health_models.py     # Comprehensive test suite
└── data/                    # Generated datasets (gitignored)
    ├── health_data.csv         # Synthetic patient data
    └── health_model.pkl        # Trained XGBoost model
```

## Testing

```bash
# Run comprehensive test suite
pytest test_health_models.py -v

# Generate coverage report
pytest --cov=. --cov-report=html

# Test specific components
pytest test_health_models.py::TestDataGeneration -v
pytest test_health_models.py::TestHealthPredictor -v
```

### Test Coverage
- Data generation validation
- Model training and prediction
- Feature engineering pipeline
- Data quality assurance
- Correlation analysis

## Privacy & Ethics

### Educational Use Only
This dashboard is designed for **educational and demonstration purposes only**. It is not intended for:
- Medical diagnosis or treatment
- Clinical decision-making
- Real patient data analysis
- Production healthcare environments

### Data Safety
- **Synthetic Data**: All patient data is artificially generated
- **No PHI**: No real personal health information is used
- **Privacy First**: No data collection or external transmission
- **Local Processing**: All computations happen locally

## Security Considerations

- **No External APIs**: All processing happens locally
- **No Data Upload**: No patient data leaves your machine
- **Educational Disclaimer**: Clear warnings about non-medical use
- **Synthetic Only**: No real health information processed

## Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup
```bash
# Install development dependencies
pip install -r requirements.txt
pip install pytest pytest-cov black flake8

# Run code formatting
black *.py

# Run linting
flake8 *.py

# Run tests before committing
pytest test_health_models.py -v
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **XGBoost Team**: Powerful gradient boosting framework
- **Streamlit**: Amazing web app framework for Python
- **Plotly**: Interactive visualization library
- **scikit-learn**: Comprehensive ML toolkit
- **Font Awesome**: Professional icon library

## Support

- **Issues**: [GitHub Issues](https://github.com/builtbymaxim/healthpulse-analytics/issues)
- **Discussions**: [GitHub Discussions](https://github.com/builtbymaxim/healthpulse-analytics/discussions)
- **Documentation**: [Project Wiki](https://github.com/builtbymaxim/healthpulse-analytics/wiki)

---

**HealthPulse Analytics** - Empowering health data science education through AI-driven insights.

*Built for the data science and healthcare communities*
