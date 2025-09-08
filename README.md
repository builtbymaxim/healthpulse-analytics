\# 🏥 HealthPulse Analytics



AI-Powered Health Intelligence \& Glucose Prediction Platform



\## 🚀 Quick Start



\### 1. Setup Environment

```bash

\# Install dependencies

pip install -r requirements.txt



\# Run automated setup

python setup.py

```



\### 2. Launch Dashboard

```bash

streamlit run healthpulse\_app.py

```



\### 3. Access Dashboard

Open: http://localhost:8501



\## 📊 Features



\- \*\*🔮 AI Glucose Prediction\*\* - 7-day forecasting with XGBoost

\- \*\*📈 Risk Assessment\*\* - Automated high-risk patient identification  

\- \*\*🎯 Interactive Analytics\*\* - Correlation analysis and feature importance

\- \*\*👤 Patient Tracking\*\* - Individual patient monitoring and trends

\- \*\*💡 Smart Recommendations\*\* - Personalized lifestyle suggestions



\## 🧪 Testing



```bash

\# Run test suite

pytest test\_health\_models.py -v



\# Test coverage

pytest --cov=. --cov-report=html

```



\## 📁 Project Structure



```

healthpulse/

├── data\_generator.py      # Synthetic data generation

├── ml\_models.py          # XGBoost training pipeline  

├── healthpulse\_app.py    # Streamlit dashboard

├── utils.py              # Helper functions

├── setup.py              # Automated setup script

├── test\_health\_models.py # Test suite

└── requirements.txt      # Dependencies

```



\## ⚡ Performance



\- \*\*Model Accuracy\*\*: ~74% R² with 25.3 mg/dL RMSE

\- \*\*Data Scale\*\*: 360K+ health measurements for 1000 patients

\- \*\*Prediction Speed\*\*: <100ms per request

\- \*\*Dashboard Load\*\*: ~3 seconds



\## 🔧 Development



```bash

\# Generate data manually

python data\_generator.py



\# Train model manually  

python ml\_models.py



\# Run specific tests

pytest test\_health\_models.py::TestDataGeneration -v

```



\## 📝 License



MIT License - see LICENSE file for details



---



\*\*Built with\*\*: Python, XGBoost, Streamlit, Plotly, scikit-learn

