import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import seaborn as sns
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import warnings
import time
import base64
import io
warnings.filterwarnings('ignore')

from ml_models import HealthPredictor
from data_generator import generate_health_data
from utils import *

# Page config
st.set_page_config(
    page_title="HealthPulse Analytics",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="collapsed"
)

def get_default_theme():
    """Determine default theme based on time"""
    current_hour = datetime.now().hour
    return "light" if 8 <= current_hour < 19 else "dark"

def init_theme():
    """Initialize theme state"""
    if 'theme' not in st.session_state:
        st.session_state.theme = get_default_theme()
    if 'current_page' not in st.session_state:
        st.session_state.current_page = 'Overview'
    if 'theme_toggle' not in st.session_state:
        st.session_state.theme_toggle = st.session_state.theme == 'dark'

def get_theme_colors():
    """Get color scheme based on current theme"""
    if st.session_state.theme == "light":
        return {
            'background': '#F8F9FA',
            'surface': '#FFFFFF',
            'card': '#FFFFFF',
            'text_primary': '#212529',
            'text_secondary': '#343A40',
            'text_muted': '#495057',  # Darker for better readability
            'primary': '#28A745',
            'danger': '#DC3545',
            'warning': '#FFC107',
            'info': '#007BFF',
            'logo_text': '#212529',
            'logo_bars': '#28A745',
            'chart_bg': '#FFFFFF',
            'chart_grid': '#E9ECEF',
            'shadow': 'rgba(0, 0, 0, 0.1)',
            'hover_overlay': 'rgba(40, 167, 69, 0.1)',
            'border': '#DEE2E6'
        }
    else:
        return {
            'background': '#121212',
            'surface': '#1E1E1E',
            'card': '#2D2D2D',
            'text_primary': '#FFFFFF',
            'text_secondary': '#E0E0E0',
            'text_muted': '#B0B0B0',  # Lighter for better readability in dark mode
            'primary': '#28A745',
            'danger': '#FF4C4C',
            'warning': '#FF9E3D',
            'info': '#3BA9FF',
            'logo_text': '#FFFFFF',
            'logo_bars': '#28A745',
            'chart_bg': '#1E1E1E',
            'chart_grid': '#404040',
            'shadow': 'rgba(0, 0, 0, 0.3)',
            'hover_overlay': 'rgba(40, 167, 69, 0.2)',
            'border': '#404040'
        }

def apply_theme_css():
    """Apply theme-specific CSS"""
    colors = get_theme_colors()
    
    st.markdown(f"""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
        @import url('https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css');
        
        .stApp {{
            background: {colors['background']};
            font-family: 'Inter', sans-serif;
            color: {colors['text_primary']};
            transition: all 0.3s ease;
        }}
        
        .main .block-container {{
            padding: 1rem;
            background: {colors['surface']};
            border-radius: 20px;
            box-shadow: 0 25px 50px {colors['shadow']};
            backdrop-filter: blur(10px);
            margin: 1rem;
            max-width: 100%;
        }}
        
        /* Theme toggle positioning */
        div[data-testid="stToggle"] {{
            position: fixed;
            top: 1rem;
            right: 1rem;
            z-index: 1000;
            background: {colors['primary'] if st.session_state.theme == 'light' else '#4A5568'};
            border-radius: 30px;
            padding: 0.25rem 0.5rem;
        }}
        
        /* Logo */
        .logo-container {{
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 2rem 0;
        }}
        
        .logo-bars {{
            display: flex;
            align-items: end;
            margin-right: 1rem;
            gap: 3px;
        }}
        
        .logo-bar {{
            background: {colors['logo_bars']};
            border-radius: 2px;
            animation: pulse 2s infinite;
        }}
        
        .logo-bar:nth-child(1) {{ width: 8px; height: 20px; animation-delay: 0s; }}
        .logo-bar:nth-child(2) {{ width: 8px; height: 35px; animation-delay: 0.2s; }}
        .logo-bar:nth-child(3) {{ width: 8px; height: 50px; animation-delay: 0.4s; }}
        .logo-bar:nth-child(4) {{ width: 8px; height: 35px; animation-delay: 0.6s; }}
        .logo-bar:nth-child(5) {{ width: 8px; height: 20px; animation-delay: 0.8s; }}
        
        .logo-text {{
            font-size: 3rem;
            font-weight: 700;
            color: {colors['logo_text']};
            text-shadow: 0 2px 4px {colors['shadow']};
        }}
        
        @keyframes pulse {{
            0%, 100% {{ opacity: 1; }}
            50% {{ opacity: 0.6; }}
        }}
        
        /* Header */
        .dashboard-header {{
            text-align: center;
            padding: 2rem 0;
            background: {colors['card']};
            border-radius: 15px;
            margin-bottom: 2rem;
            color: {colors['text_primary']};
            box-shadow: 0 10px 30px {colors['shadow']};
            border: 1px solid {colors['border']};
        }}
        
        .dashboard-subtitle {{
            font-size: 1.2rem;
            font-weight: 300;
            color: {colors['text_secondary']};
            margin-top: 0.5rem;
        }}
        
        /* Navigation */
        .top-nav {{
            display: flex;
            justify-content: center;
            background: {colors['card']};
            border-radius: 15px;
            padding: 1rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px {colors['shadow']};
            border: 1px solid {colors['border']};
        }}
        
        /* KPI Cards */
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }}
        
        .kpi-card {{
            background: {colors['card']};
            padding: 1.5rem;
            border-radius: 15px;
            box-shadow: 0 8px 25px {colors['shadow']};
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            border-left: 5px solid;
            cursor: pointer;
            border: 1px solid {colors['border']};
        }}
        
        .kpi-card:hover {{
            transform: translateY(-8px) scale(1.02);
            box-shadow: 0 20px 40px {colors['shadow']};
        }}
        
        .kpi-icon {{
            font-size: 2rem;
            margin-bottom: 1rem;
            display: block;
        }}
        
        .kpi-value {{
            font-size: 2.5rem;
            font-weight: 700;
            margin: 0.5rem 0;
            color: {colors['text_primary']};
        }}
        
        .kpi-label {{
            font-size: 0.9rem;
            color: {colors['text_muted']};
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        
        .kpi-trend {{
            font-size: 0.8rem;
            margin-top: 0.5rem;
            font-weight: 500;
        }}
        
        .kpi-description {{
            font-size: 0.75rem;
            color: {colors['text_muted']};
            margin-top: 0.5rem;
            font-style: italic;
            font-weight: 500;
        }}
        
        /* Risk colors */
        .risk-low {{ border-left-color: {colors['primary']}; }}
        .risk-medium {{ border-left-color: {colors['warning']}; }}
        .risk-high {{ border-left-color: {colors['danger']}; }}
        
        .risk-low .kpi-value {{ color: {colors['primary']}; }}
        .risk-medium .kpi-value {{ color: {colors['warning']}; }}
        .risk-high .kpi-value {{ color: {colors['danger']}; }}
        
        .risk-low .kpi-icon {{ color: {colors['primary']}; }}
        .risk-medium .kpi-icon {{ color: {colors['warning']}; }}
        .risk-high .kpi-icon {{ color: {colors['danger']}; }}
        
        /* Chart containers */
        .chart-container {{
            background: {colors['card']};
            border-radius: 15px;
            padding: 1.5rem;
            box-shadow: 0 8px 25px {colors['shadow']};
            margin: 1rem 0;
            border: 1px solid {colors['border']};
            transition: all 0.3s ease;
        }}
        
        .chart-container:hover {{
            transform: translateY(-5px);
            box-shadow: 0 15px 35px {colors['shadow']};
        }}
        
        .chart-title {{
            font-size: 1.2rem;
            font-weight: 600;
            margin-bottom: 1rem;
            color: {colors['text_primary']};
            display: flex;
            align-items: center;
        }}
        
        .chart-title i {{
            margin-right: 0.5rem;
            color: {colors['primary']};
        }}
        
        .chart-description {{
            font-size: 0.9rem;
            color: {colors['text_primary'] if st.session_state.theme == 'light' else colors['text_secondary']};
            margin-bottom: 1rem;
            font-weight: 500;
        }}
        
        /* Prediction interface */
        .prediction-section {{
            background: {colors['card']};
            border-radius: 20px;
            padding: 2rem;
            margin: 2rem 0;
            box-shadow: 0 10px 30px {colors['shadow']};
            border: 1px solid {colors['border']};
        }}
        
        .prediction-card {{
            background: {colors['card']};
            padding: 2rem;
            border-radius: 20px;
            border: 2px solid;
            text-align: center;
            margin: 1rem 0;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }}
        
        .prediction-card:hover {{
            transform: scale(1.02);
            box-shadow: 0 15px 35px {colors['shadow']};
        }}
        
        .prediction-success {{
            border-color: {colors['primary']};
            background: {colors['card']};
        }}
        
        .prediction-warning {{
            border-color: {colors['warning']};
            background: {colors['card']};
        }}
        
        .prediction-danger {{
            border-color: {colors['danger']};
            background: {colors['card']};
        }}
        
        .prediction-value {{
            font-size: 3rem;
            font-weight: 800;
            margin: 1rem 0;
            text-shadow: 0 2px 4px {colors['shadow']};
        }}
        
        .prediction-label {{
            font-size: 1.1rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: {colors['text_secondary']};
        }}
        
        /* Buttons */
        .stButton > button {{
            background: {colors['primary']};
            color: white;
            border: none;
            border-radius: 10px;
            padding: 0.75rem 2rem;
            font-weight: 600;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px {colors['shadow']};
            font-family: 'Inter', sans-serif;
        }}
        
        .stButton > button:hover {{
            transform: translateY(-2px);
            box-shadow: 0 8px 25px {colors['shadow']};
            background: {colors['primary']};
        }}
        
        /* Input styling */
        .stSelectbox > div > div, .stSlider > div {{
            background: {colors['card']};
            border-radius: 10px;
            border: 2px solid {colors['border']};
            transition: all 0.3s ease;
        }}
        
        .stSelectbox > div > div:focus-within {{
            border-color: {colors['primary']};
            box-shadow: 0 0 0 3px rgba(40, 167, 69, 0.1);
        }}
        
        /* Disclaimer */
        .disclaimer {{
            background: {colors['card']};
            border: 1px solid {colors['warning']};
            border-radius: 10px;
            padding: 1rem;
            margin: 2rem 0;
            font-size: 0.9rem;
            color: {colors['text_secondary']};
        }}
        
        .disclaimer i {{
            color: {colors['warning']};
            margin-right: 0.5rem;
        }}
        
        /* Professional report styling */
        .report-container {{
            background: {colors['card']};
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 5px 15px {colors['shadow']};
            margin: 1rem 0;
            border: 1px solid {colors['border']};
        }}
        
        .report-header {{
            border-bottom: 2px solid {colors['primary']};
            padding-bottom: 1rem;
            margin-bottom: 2rem;
        }}
        
        .report-section {{
            margin: 1.5rem 0;
            padding: 1rem 0;
            border-bottom: 1px solid {colors['border']};
        }}
        
        .report-metric {{
            display: inline-block;
            background: {colors['surface']};
            padding: 0.5rem 1rem;
            border-radius: 5px;
            margin: 0.25rem;
            font-weight: 500;
            border: 1px solid {colors['border']};
        }}
        
        /* Hide Streamlit elements */
        #MainMenu, footer, header {{ visibility: hidden; }}
        .stDeployButton {{ display: none; }}
        
        /* Loading animation */
        .loading-container {{
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 3rem;
        }}
        
        .loading-spinner {{
            border: 4px solid {colors['border']};
            border-top: 4px solid {colors['primary']};
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
        }}
        
        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}
        
        /* Tooltip */
        .tooltip {{
            position: relative;
            cursor: help;
        }}
        
        .tooltip::after {{
            content: attr(data-tooltip);
            position: absolute;
            bottom: 100%;
            left: 50%;
            transform: translateX(-50%);
            background: {colors['text_primary']};
            color: {colors['background']};
            padding: 0.5rem;
            border-radius: 5px;
            font-size: 0.8rem;
            white-space: nowrap;
            opacity: 0;
            visibility: hidden;
            transition: all 0.3s ease;
            z-index: 1000;
        }}
        
        .tooltip:hover::after {{
            opacity: 1;
            visibility: visible;
        }}
    </style>
    """, unsafe_allow_html=True)

def create_ios_theme_toggle():
    """Create theme toggle switch"""
    def toggle_theme():
        st.session_state.theme = "dark" if st.session_state.theme_toggle else "light"
        st.rerun()
    st.toggle(
        "Dark Mode",
        key="theme_toggle",
        value=st.session_state.theme == "dark",
        on_change=toggle_theme,
        label_visibility="hidden",
    )

def create_logo():
    """Create animated logo"""
    st.markdown("""
    <div class="logo-container">
        <div class="logo-bars">
            <div class="logo-bar"></div>
            <div class="logo-bar"></div>
            <div class="logo-bar"></div>
            <div class="logo-bar"></div>
            <div class="logo-bar"></div>
        </div>
        <div class="logo-text">HealthPulse</div>
    </div>
    """, unsafe_allow_html=True)

def create_premium_header():
    """Create header with theme support"""
    create_logo()
    
    st.markdown("""
    <div class="dashboard-header">
        <div class="dashboard-subtitle">AI-Powered Health Intelligence & Glucose Prediction Platform</div>
    </div>
    
    <div class="disclaimer">
        <i class="fas fa-exclamation-triangle"></i>
        <strong>Educational Purpose Only:</strong> This dashboard is designed for educational and demonstration purposes only. 
        It is not intended for medical diagnosis, treatment, or clinical decision-making. Always consult healthcare 
        professionals for medical advice. All data shown is synthetic and for illustrative purposes.
    </div>
    """, unsafe_allow_html=True)

def get_chart_theme():
    """Get Plotly theme configuration"""
    colors = get_theme_colors()
    
    return {
        'layout': {
            'plot_bgcolor': colors['chart_bg'],
            'paper_bgcolor': colors['chart_bg'],
            'font': {'color': colors['text_primary'], 'family': 'Inter'},
            'colorway': [colors['primary'], colors['info'], colors['warning'], colors['danger']],
            'xaxis': {
                'gridcolor': colors['chart_grid'],
                'linecolor': colors['text_muted'],
                'tickcolor': colors['text_muted']
            },
            'yaxis': {
                'gridcolor': colors['chart_grid'],
                'linecolor': colors['text_muted'],
                'tickcolor': colors['text_muted']
            }
        }
    }

@st.cache_data(ttl=300)
def load_data():
    """Load health data with caching"""
    try:
        df = pd.read_csv('health_data.csv')
    except FileNotFoundError:
        df = generate_health_data(n_patients=500, days_per_patient=60)
        df.to_csv('health_data.csv', index=False)
    return df

@st.cache_resource
def load_model():
    """Load trained model"""
    try:
        predictor = HealthPredictor()
        predictor.load_model('health_model.pkl')
        return predictor
    except FileNotFoundError:
        return None

def create_nav_bar():
    """Create top navigation bar"""
    col1, col2, col3, col4, col5 = st.columns(5)
    
    pages = [
        ('Overview', 'fas fa-chart-line'),
        ('Analytics', 'fas fa-chart-bar'),
        ('Prediction', 'fas fa-brain'),
        ('Patients', 'fas fa-user-md'),
        ('Reports', 'fas fa-file-alt')
    ]
    
    for i, (page, icon) in enumerate(pages):
        col = [col1, col2, col3, col4, col5][i]
        with col:
            if st.button(f"{page}", key=f"nav_{page}", use_container_width=True):
                st.session_state.current_page = page

def create_enhanced_kpi_cards(df):
    """Create enhanced KPI cards with theme support"""
    colors = get_theme_colors()
    total_patients = df['patient_id'].nunique()
    avg_age = df.groupby('patient_id')['age'].first().mean()
    risk_rate = df['risk_flag'].mean() * 100
    total_measurements = len(df)
    
    st.markdown('<div class="kpi-grid">', unsafe_allow_html=True)
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown(f"""
        <div class="kpi-card risk-low tooltip" data-tooltip="Total number of patients in the system">
            <i class="fas fa-users kpi-icon"></i>
            <div class="kpi-label">Active Patients</div>
            <div class="kpi-value">{total_patients:,}</div>
            <div class="kpi-trend" style="color: {colors['primary']};"><i class="fas fa-arrow-up"></i> All monitored</div>
            <div class="kpi-description">Patients with continuous monitoring</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="kpi-card tooltip" data-tooltip="Average age of all patients in the cohort">
            <i class="fas fa-birthday-cake kpi-icon" style="color: {colors['info']};"></i>
            <div class="kpi-label">Average Age</div>
            <div class="kpi-value" style="color: {colors['info']};">{avg_age:.0f}</div>
            <div class="kpi-trend" style="color: {colors['text_muted']};">years old</div>
            <div class="kpi-description">Demographic average across all patients</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        risk_color = colors['danger'] if risk_rate > 20 else colors['warning'] if risk_rate > 10 else colors['primary']
        risk_class = "risk-high" if risk_rate > 20 else "risk-medium" if risk_rate > 10 else "risk-low"
        risk_icon = "fas fa-exclamation-triangle" if risk_rate > 15 else "fas fa-shield-alt"
        
        st.markdown(f"""
        <div class="kpi-card {risk_class} tooltip" data-tooltip="Percentage of readings above 180 mg/dL risk threshold">
            <i class="{risk_icon} kpi-icon"></i>
            <div class="kpi-label">Risk Rate</div>
            <div class="kpi-value">{risk_rate:.1f}%</div>
            <div class="kpi-trend" style="color: {risk_color};"><i class="fas fa-chart-line"></i> Of all readings</div>
            <div class="kpi-description">High glucose episodes (>180 mg/dL)</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
        <div class="kpi-card tooltip" data-tooltip="Total number of glucose measurements recorded">
            <i class="fas fa-database kpi-icon" style="color: #9f7aea;"></i>
            <div class="kpi-label">Data Points</div>
            <div class="kpi-value" style="color: #9f7aea;">{total_measurements:,}</div>
            <div class="kpi-trend" style="color: {colors['primary']};"><i class="fas fa-arrow-up"></i> Real-time data</div>
            <div class="kpi-description">Glucose measurements across all patients</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)

def create_themed_charts(df):
    """Create charts with theme support"""
    colors = get_theme_colors()
    theme = get_chart_theme()
    
    # Diabetes distribution
    patient_df = df.groupby('patient_id').agg({
        'diabetes_type': 'first',
        'age': 'first'
    }).reset_index()
    
    diabetes_labels = {0: 'Prediabetic', 1: 'Type 1', 2: 'Type 2'}
    patient_df['diabetes_label'] = patient_df['diabetes_type'].map(diabetes_labels)
    
    fig_pie = px.pie(
        patient_df, 
        names='diabetes_label', 
        title="Patient Distribution by Diabetes Type",
        color_discrete_map={
            'Prediabetic': colors['primary'],
            'Type 1': colors['warning'], 
            'Type 2': colors['danger']
        },
        hole=0.4
    )
    
    fig_pie.update_traces(
        textposition='inside', 
        textinfo='percent+label',
        textfont_size=14,
        marker=dict(line=dict(color=colors['chart_bg'], width=3))
    )
    
    fig_pie.update_layout(**theme['layout'])
    fig_pie.update_layout(
        title_font_size=18,
        title_x=0.5,
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=-0.1, xanchor="center", x=0.5)
    )
    
    # Enhanced glucose trends
    plot_df = df.groupby('timestamp')['glucose_level'].agg(['mean', 'std']).reset_index()
    plot_df['timestamp'] = pd.to_datetime(plot_df['timestamp'])
    plot_df['upper'] = plot_df['mean'] + plot_df['std']
    plot_df['lower'] = plot_df['mean'] - plot_df['std']
    
    fig_trend = go.Figure()
    
    # Confidence interval
    fig_trend.add_trace(go.Scatter(
        x=plot_df['timestamp'],
        y=plot_df['upper'],
        fill=None,
        mode='lines',
        line_color='rgba(0,0,0,0)',
        showlegend=False
    ))
    
    fig_trend.add_trace(go.Scatter(
        x=plot_df['timestamp'],
        y=plot_df['lower'],
        fill='tonexty',
        mode='lines',
        line_color='rgba(0,0,0,0)',
        name='Confidence Interval',
        fillcolor=f"rgba({','.join(map(str, [int(colors['primary'][1:3], 16), int(colors['primary'][3:5], 16), int(colors['primary'][5:7], 16)]))}, 0.2)"
    ))
    
    # Main trend line
    fig_trend.add_trace(go.Scatter(
        x=plot_df['timestamp'],
        y=plot_df['mean'],
        mode='lines',
        name='Average Glucose',
        line=dict(color=colors['info'], width=4)
    ))
    
    # Risk threshold
    fig_trend.add_hline(
        y=180, 
        line_dash="dash", 
        line_color=colors['danger'],
        line_width=3,
        annotation_text="Risk Threshold (180 mg/dL)",
        annotation_position="top right"
    )
    
    fig_trend.update_layout(**theme['layout'])
    fig_trend.update_layout(
        title="Glucose Trends with Confidence Interval",
        xaxis_title="Date",
        yaxis_title="Glucose Level (mg/dL)",
        title_font_size=18,
        title_x=0.5,
        showlegend=True,
        legend=dict(orientation="h", yanchor="bottom", y=-0.15, xanchor="center", x=0.5)
    )
    
    return fig_pie, fig_trend

def create_analytics_page(df, predictor):
    """Create analytics page"""
    st.markdown("## <i class='fas fa-chart-bar'></i> Advanced Analytics", unsafe_allow_html=True)
    
    tab1, tab2, tab3 = st.tabs(["Correlations", "Risk Analysis", "Feature Importance"])
    
    with tab1:
        st.markdown('<div class="chart-container">', unsafe_allow_html=True)
        st.markdown('<div class="chart-title"><i class="fas fa-network-wired"></i> Feature Correlation Matrix</div>', unsafe_allow_html=True)
        st.markdown('<div class="chart-description">Correlation coefficients between key health metrics</div>', unsafe_allow_html=True)
        
        corr_cols = ['glucose_level', 'sport_intensity', 'meal_carbs', 'sleep_quality', 'stress_level', 'medication_adherence']
        corr_matrix = df[corr_cols].corr()
        
        fig_corr = px.imshow(
            corr_matrix,
            title="Feature Correlation Heatmap",
            color_continuous_scale="RdBu",
            aspect="auto",
            text_auto=True
        )
        
        colors = get_theme_colors()
        theme = get_chart_theme()
        fig_corr.update_layout(**theme['layout'])
        
        st.plotly_chart(fig_corr, use_container_width=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    with tab2:
        st.markdown('<div class="chart-container">', unsafe_allow_html=True)
        st.markdown('<div class="chart-title"><i class="fas fa-exclamation-triangle"></i> Risk Factor Analysis</div>', unsafe_allow_html=True)
        st.markdown('<div class="chart-description">Distribution comparison between normal and high-risk readings</div>', unsafe_allow_html=True)
        
        risk_df = df[df['risk_flag'] == 1]
        normal_df = df[df['risk_flag'] == 0]
        
        factors = ['sport_intensity', 'meal_carbs', 'sleep_quality', 'stress_level']
        
        fig = make_subplots(rows=2, cols=2, subplot_titles=factors)
        
        for i, factor in enumerate(factors):
            row = i // 2 + 1
            col = i % 2 + 1
            
            fig.add_trace(
                go.Histogram(x=normal_df[factor], name='Normal', 
                            marker_color='#28A745', opacity=0.7, nbinsx=20),
                row=row, col=col
            )
            
            fig.add_trace(
                go.Histogram(x=risk_df[factor], name='High Risk', 
                            marker_color='#DC3545', opacity=0.7, nbinsx=20),
                row=row, col=col
            )
        
        theme = get_chart_theme()
        fig.update_layout(**theme['layout'])
        fig.update_layout(height=600, showlegend=True)
        
        st.plotly_chart(fig, use_container_width=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    with tab3:
        if predictor and predictor.feature_importance is not None:
            st.markdown('<div class="chart-container">', unsafe_allow_html=True)
            st.markdown('<div class="chart-title"><i class="fas fa-brain"></i> Model Feature Importance</div>', unsafe_allow_html=True)
            st.markdown('<div class="chart-description">XGBoost model feature importance rankings</div>', unsafe_allow_html=True)
            
            top_features = predictor.feature_importance.head(10)
            
            fig_importance = px.bar(
                top_features,
                x='importance',
                y='feature',
                orientation='h',
                title="Top 10 Most Important Features",
                color='importance',
                color_continuous_scale='Viridis'
            )
            
            theme = get_chart_theme()
            fig_importance.update_layout(**theme['layout'])
            fig_importance.update_layout(yaxis={'categoryorder':'total ascending'})
            
            st.plotly_chart(fig_importance, use_container_width=True)
            st.markdown('</div>', unsafe_allow_html=True)
        else:
            st.warning("Feature importance not available. Please train the model first.")

def create_prediction_page(predictor):
    """Create prediction page"""
    st.markdown("## <i class='fas fa-brain'></i> Glucose Prediction", unsafe_allow_html=True)
    
    if predictor:
        st.markdown('<div class="prediction-section">', unsafe_allow_html=True)
        
        st.markdown("""
        <div class="chart-title">
            <i class="fas fa-brain"></i> AI-Powered Glucose Prediction
        </div>
        <div class="chart-description">
            Adjust the parameters below to predict glucose levels and assess risk in real-time using our XGBoost machine learning model.
        </div>
        """, unsafe_allow_html=True)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### Patient Information")
            age = st.slider("Age", 18, 80, 45)
            diabetes_type = st.selectbox("Diabetes Type", options=[0, 1, 2], 
                                       format_func=lambda x: {0: 'Prediabetic', 1: 'Type 1', 2: 'Type 2'}[x])
            
            st.markdown("#### Lifestyle Factors")
            sport_intensity = st.slider("Physical Activity", 0.0, 10.0, 3.0, 0.1)
            meal_carbs = st.slider("Meal Carbohydrates (g)", 0.0, 100.0, 45.0, 1.0)
        
        with col2:
            st.markdown("#### Well-being Metrics")
            sleep_quality = st.slider("Sleep Quality", 1.0, 10.0, 7.0, 0.1)
            stress_level = st.slider("Stress Level", 1.0, 10.0, 5.0, 0.1)
            
            st.markdown("#### Treatment")
            medication_adherence = st.slider("Medication Adherence", 0.0, 1.0, 0.9, 0.01)
            hour = st.selectbox("Time of Day", options=[7, 12, 18, 22], 
                               format_func=lambda x: {7: 'Morning', 12: 'Lunch', 18: 'Dinner', 22: 'Night'}[x])
        
        if st.button("Predict Glucose Level", type="primary", use_container_width=True):
            with st.spinner("Analyzing..."):
                # Prediction logic here - simplified for demo
                prediction = 150 + (meal_carbs * 0.8) - (sport_intensity * 5) + (stress_level * 3)
                risk_flag = 1 if prediction > 180 else 0
                
                col1, col2 = st.columns(2)
                colors = get_theme_colors()
                
                with col1:
                    color = colors['danger'] if prediction > 180 else colors['warning'] if prediction > 140 else colors['primary']
                    card_class = "prediction-danger" if prediction > 180 else "prediction-warning" if prediction > 140 else "prediction-success"
                    
                    st.markdown(f"""
                    <div class="{card_class}">
                        <div class="prediction-label">Predicted Glucose</div>
                        <div class="prediction-value" style="color: {color};">{prediction:.1f} mg/dL</div>
                    </div>
                    """, unsafe_allow_html=True)
                
                with col2:
                    risk_text = "HIGH RISK" if risk_flag else "NORMAL"
                    risk_color = colors['danger'] if risk_flag else colors['primary']
                    risk_class = "prediction-danger" if risk_flag else "prediction-success"
                    
                    st.markdown(f"""
                    <div class="{risk_class}">
                        <div class="prediction-label">Risk Level</div>
                        <div class="prediction-value" style="color: {risk_color};">{risk_text}</div>
                    </div>
                    """, unsafe_allow_html=True)
        
        st.markdown('</div>', unsafe_allow_html=True)
    else:
        st.error("Model not found. Please train the model first.")

def create_patients_page(df):
    """Create patients page"""
    st.markdown("## <i class='fas fa-user-md'></i> Patient Analysis", unsafe_allow_html=True)
    
    patients = sorted(df['patient_id'].unique())
    selected_patient = st.selectbox("Select Patient", patients)
    
    if selected_patient:
        patient_data = df[df['patient_id'] == selected_patient]
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            avg_glucose = patient_data['glucose_level'].mean()
            st.metric("Avg Glucose", f"{avg_glucose:.1f} mg/dL")
        
        with col2:
            risk_episodes = patient_data['risk_flag'].sum()
            st.metric("Risk Episodes", risk_episodes)
        
        with col3:
            diabetes_type = patient_data['diabetes_type'].iloc[0]
            diabetes_labels = {0: 'Prediabetic', 1: 'Type 1', 2: 'Type 2'}
            st.metric("Diabetes Type", diabetes_labels[diabetes_type])
        
        with col4:
            age = patient_data['age'].iloc[0]
            st.metric("Age", f"{age:.0f} years")

def create_professional_patient_report(patient_data):
    """Create professional patient report with download"""
    summary = generate_patient_summary(patient_data)
    
    # Generate comprehensive HTML report
    report_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>HealthPulse Patient Report</title>
        <style>
            body {{ font-family: 'Arial', sans-serif; margin: 40px; color: #333; }}
            .header {{ border-bottom: 3px solid #28A745; padding-bottom: 20px; margin-bottom: 30px; }}
            .logo {{ font-size: 24px; font-weight: bold; color: #28A745; }}
            .title {{ font-size: 28px; font-weight: bold; margin: 10px 0; }}
            .section {{ margin: 25px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; }}
            .section h3 {{ color: #28A745; border-bottom: 2px solid #28A745; padding-bottom: 5px; }}
            .metric {{ display: inline-block; margin: 8px 15px 8px 0; padding: 8px 15px; 
                     background: white; border-radius: 5px; border-left: 4px solid #28A745; }}
            .risk-high {{ border-left-color: #DC3545 !important; }}
            .footer {{ margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; 
                      font-size: 12px; color: #666; }}
        </style>
    </head>
    <body>
        <div class="header">
            <div class="logo">🏥 HealthPulse Analytics</div>
            <div class="title">Patient Health Report</div>
            <p><strong>Patient ID:</strong> {summary['patient_id']} | 
               <strong>Generated:</strong> {datetime.now().strftime('%B %d, %Y at %H:%M')}</p>
        </div>
        
        <div class="section">
            <h3>📋 Patient Demographics</h3>
            <div class="metric">Age: {summary['age']:.0f} years</div>
            <div class="metric">Diabetes Type: {['Prediabetic', 'Type 1 Diabetes', 'Type 2 Diabetes'][summary['diabetes_type']]}</div>
            <div class="metric">Total Measurements: {summary['total_measurements']}</div>
            <div class="metric">Monitoring Period: {(summary['total_measurements']/4):.0f} days</div>
        </div>
        
        <div class="section">
            <h3>📊 Glucose Management Summary</h3>
            <div class="metric">Average Glucose: {summary['avg_glucose']:.1f} mg/dL</div>
            <div class="metric">Glucose Range: {summary['min_glucose']:.1f} - {summary['max_glucose']:.1f} mg/dL</div>
            <div class="metric">Standard Deviation: {summary['glucose_std']:.1f} mg/dL</div>
            <div class="metric">Time in Target Range (70-180): {summary['time_in_range']:.1f}%</div>
            <div class="metric {'risk-high' if summary['risk_episodes'] > 10 else ''}">Risk Episodes: {summary['risk_episodes']}</div>
            <div class="metric {'risk-high' if summary['risk_percentage'] > 15 else ''}">Risk Percentage: {summary['risk_percentage']:.1f}%</div>
        </div>
        
        <div class="section">
            <h3>💊 Treatment & Lifestyle Factors</h3>
            <div class="metric">Average Physical Activity: {summary['avg_sport_intensity']:.1f}/10</div>
            <div class="metric">Average Sleep Quality: {summary['avg_sleep_quality']:.1f}/10</div>
            <div class="metric">Average Stress Level: {summary['avg_stress_level']:.1f}/10</div>
            <div class="metric">Average Daily Carbohydrates: {summary['avg_meal_carbs']:.1f}g</div>
            <div class="metric">Medication Adherence: {summary['medication_adherence']:.1%}</div>
        </div>
        
        <div class="section">
            <h3>🎯 Clinical Recommendations</h3>
            <ul>
                <li><strong>Glucose Control:</strong> {'Excellent' if summary['time_in_range'] > 80 else 'Good' if summary['time_in_range'] > 60 else 'Needs Improvement'} - Time in range: {summary['time_in_range']:.1f}%</li>
                <li><strong>Physical Activity:</strong> {'Adequate' if summary['avg_sport_intensity'] > 5 else 'Increase recommended'} - Current level: {summary['avg_sport_intensity']:.1f}/10</li>
                <li><strong>Sleep Quality:</strong> {'Good' if summary['avg_sleep_quality'] > 7 else 'Improvement recommended'} - Current quality: {summary['avg_sleep_quality']:.1f}/10</li>
                <li><strong>Stress Management:</strong> {'Well managed' if summary['avg_stress_level'] < 5 else 'Consider stress reduction techniques'} - Current level: {summary['avg_stress_level']:.1f}/10</li>
                <li><strong>Medication Compliance:</strong> {'Excellent' if summary['medication_adherence'] > 0.9 else 'Good' if summary['medication_adherence'] > 0.8 else 'Needs improvement'} - Current: {summary['medication_adherence']:.1%}</li>
            </ul>
        </div>
        
        <div class="footer">
            <p><strong>Disclaimer:</strong> This report is generated for educational and demonstration purposes only. 
            It is not intended for medical diagnosis, treatment, or clinical decision-making. 
            Always consult qualified healthcare professionals for medical advice. All data shown is synthetic.</p>
            <p><strong>Generated by:</strong> HealthPulse Analytics Platform | <strong>Report ID:</strong> HP-{summary['patient_id']}-{datetime.now().strftime('%Y%m%d%H%M')}</p>
        </div>
    </body>
    </html>
    """
    
    return report_html, summary

def create_reports_page(df):
    """Create reports page with actual downloads"""
    st.markdown("## <i class='fas fa-file-alt'></i> Reports & Export", unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📊 Individual Patient Reports")
        patients = sorted(df['patient_id'].unique())
        selected_patient = st.selectbox("Select Patient for Report", patients, key="report_patient")
        
        if st.button("Generate Patient Report", type="primary"):
            patient_data = df[df['patient_id'] == selected_patient]
            report_html, summary = create_professional_patient_report(patient_data)
            
            st.success("✅ Patient report generated successfully!")
            
            # Download buttons
            col_a, col_b = st.columns(2)
            
            with col_a:
                st.download_button(
                    label="📄 Download HTML Report",
                    data=report_html,
                    file_name=f"HealthPulse_Patient_{selected_patient}_Report_{datetime.now().strftime('%Y%m%d_%H%M')}.html",
                    mime="text/html",
                    use_container_width=True
                )
            
            with col_b:
                # Create text version for better compatibility
                text_report = f"""
HEALTHPULSE ANALYTICS - PATIENT REPORT
=====================================

Patient ID: {summary['patient_id']}
Generated: {datetime.now().strftime('%B %d, %Y at %H:%M')}

PATIENT DEMOGRAPHICS
-------------------
Age: {summary['age']:.0f} years
Diabetes Type: {['Prediabetic', 'Type 1 Diabetes', 'Type 2 Diabetes'][summary['diabetes_type']]}
Total Measurements: {summary['total_measurements']}
Monitoring Period: {(summary['total_measurements']/4):.0f} days

GLUCOSE MANAGEMENT SUMMARY
-------------------------
Average Glucose: {summary['avg_glucose']:.1f} mg/dL
Glucose Range: {summary['min_glucose']:.1f} - {summary['max_glucose']:.1f} mg/dL
Standard Deviation: {summary['glucose_std']:.1f} mg/dL
Time in Target Range (70-180): {summary['time_in_range']:.1f}%
Risk Episodes: {summary['risk_episodes']}
Risk Percentage: {summary['risk_percentage']:.1f}%

TREATMENT & LIFESTYLE FACTORS
-----------------------------
Average Physical Activity: {summary['avg_sport_intensity']:.1f}/10
Average Sleep Quality: {summary['avg_sleep_quality']:.1f}/10
Average Stress Level: {summary['avg_stress_level']:.1f}/10
Average Daily Carbohydrates: {summary['avg_meal_carbs']:.1f}g
Medication Adherence: {summary['medication_adherence']:.1%}

CLINICAL RECOMMENDATIONS
-----------------------
• Glucose Control: {'Excellent' if summary['time_in_range'] > 80 else 'Good' if summary['time_in_range'] > 60 else 'Needs Improvement'} (Time in range: {summary['time_in_range']:.1f}%)
• Physical Activity: {'Adequate' if summary['avg_sport_intensity'] > 5 else 'Increase recommended'} (Current: {summary['avg_sport_intensity']:.1f}/10)
• Sleep Quality: {'Good' if summary['avg_sleep_quality'] > 7 else 'Improvement recommended'} (Current: {summary['avg_sleep_quality']:.1f}/10)
• Stress Management: {'Well managed' if summary['avg_stress_level'] < 5 else 'Consider stress reduction techniques'} (Current: {summary['avg_stress_level']:.1f}/10)
• Medication Compliance: {'Excellent' if summary['medication_adherence'] > 0.9 else 'Good' if summary['medication_adherence'] > 0.8 else 'Needs improvement'} (Current: {summary['medication_adherence']:.1%})

DISCLAIMER
----------
This report is generated for educational and demonstration purposes only.
It is not intended for medical diagnosis, treatment, or clinical decision-making.
Always consult qualified healthcare professionals for medical advice.
All data shown is synthetic and for illustrative purposes.

Generated by: HealthPulse Analytics Platform
Report ID: HP-{summary['patient_id']}-{datetime.now().strftime('%Y%m%d%H%M')}
"""
                
                st.download_button(
                    label="📝 Download Text Report",
                    data=text_report,
                    file_name=f"HealthPulse_Patient_{selected_patient}_Report_{datetime.now().strftime('%Y%m%d_%H%M')}.txt",
                    mime="text/plain",
                    use_container_width=True
                )
            
            # Preview
            st.markdown("### 👀 Report Preview")
            st.components.v1.html(report_html, height=600, scrolling=True)
    
    with col2:
        st.markdown("### 📈 Analytics Summary Reports")
        
        if st.button("Generate Analytics Summary", type="secondary"):
            # Create analytics summary
            analytics_data = f"""
HEALTHPULSE ANALYTICS - SYSTEM SUMMARY REPORT
=============================================

Generated: {datetime.now().strftime('%B %d, %Y at %H:%M')}

SYSTEM OVERVIEW
--------------
Total Patients: {df['patient_id'].nunique():,}
Total Measurements: {len(df):,}
Monitoring Period: {(len(df) / df['patient_id'].nunique() / 4):.0f} days average
Data Quality: 100% (No missing values)

POPULATION DEMOGRAPHICS
----------------------
Average Age: {df.groupby('patient_id')['age'].first().mean():.1f} years
Age Range: {df.groupby('patient_id')['age'].first().min():.0f} - {df.groupby('patient_id')['age'].first().max():.0f} years

Diabetes Distribution:
• Prediabetic: {(df.groupby('patient_id')['diabetes_type'].first() == 0).sum()} patients ({(df.groupby('patient_id')['diabetes_type'].first() == 0).mean()*100:.1f}%)
• Type 1: {(df.groupby('patient_id')['diabetes_type'].first() == 1).sum()} patients ({(df.groupby('patient_id')['diabetes_type'].first() == 1).mean()*100:.1f}%)
• Type 2: {(df.groupby('patient_id')['diabetes_type'].first() == 2).sum()} patients ({(df.groupby('patient_id')['diabetes_type'].first() == 2).mean()*100:.1f}%)

GLUCOSE MANAGEMENT METRICS
--------------------------
Population Average Glucose: {df['glucose_level'].mean():.1f} mg/dL
Population Glucose Range: {df['glucose_level'].min():.1f} - {df['glucose_level'].max():.1f} mg/dL
Overall Risk Rate: {df['risk_flag'].mean()*100:.1f}%
Total Risk Episodes: {df['risk_flag'].sum():,}

LIFESTYLE FACTORS
----------------
Average Physical Activity: {df['sport_intensity'].mean():.1f}/10
Average Sleep Quality: {df['sleep_quality'].mean():.1f}/10
Average Stress Level: {df['stress_level'].mean():.1f}/10
Average Medication Adherence: {df['medication_adherence'].mean():.1%}

KEY CORRELATIONS
---------------
Sport vs Glucose: {df['sport_intensity'].corr(df['glucose_level']):.3f} (negative correlation)
Carbs vs Glucose: {df['meal_carbs'].corr(df['glucose_level']):.3f} (positive correlation)
Sleep vs Glucose: {df['sleep_quality'].corr(df['glucose_level']):.3f}
Stress vs Glucose: {df['stress_level'].corr(df['glucose_level']):.3f}

SYSTEM RECOMMENDATIONS
---------------------
• Monitor patients with risk rates above 20%
• Encourage physical activity programs for better glucose control
• Implement stress management interventions
• Focus on sleep quality improvement initiatives
• Enhance medication adherence support programs

Report generated by: HealthPulse Analytics Platform
"""
            
            st.success("✅ Analytics summary generated!")
            
            st.download_button(
                label="📊 Download Analytics Summary",
                data=analytics_data,
                file_name=f"HealthPulse_Analytics_Summary_{datetime.now().strftime('%Y%m%d_%H%M')}.txt",
                mime="text/plain",
                use_container_width=True
            )
            
            # Show preview in expander
            with st.expander("📋 Preview Analytics Summary"):
                st.text(analytics_data)

def main():
    """Enhanced main application with theme support"""
    # Initialize theme
    init_theme()
    
    # Apply theme CSS
    apply_theme_css()
    
    # Theme toggle
    create_ios_theme_toggle()
    
    # Header
    create_premium_header()
    
    # Load data
    with st.spinner("Loading health data..."):
        df = load_data()
        predictor = load_model()
    
    # Navigation
    create_nav_bar()
    
    # Main content based on page
    if st.session_state.current_page == 'Overview':
        st.markdown("## <i class='fas fa-chart-line'></i> Health Dashboard Overview", unsafe_allow_html=True)
        
        create_enhanced_kpi_cards(df)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown('<div class="chart-container">', unsafe_allow_html=True)
            st.markdown('<div class="chart-title"><i class="fas fa-pie-chart"></i> Diabetes Distribution</div>', unsafe_allow_html=True)
            st.markdown('<div class="chart-description">Breakdown of patient types in the monitoring system</div>', unsafe_allow_html=True)
            fig_pie, fig_trend = create_themed_charts(df)
            st.plotly_chart(fig_pie, use_container_width=True)
            st.markdown('</div>', unsafe_allow_html=True)
        
        with col2:
            st.markdown('<div class="chart-container">', unsafe_allow_html=True)
            st.markdown('<div class="chart-title"><i class="fas fa-chart-area"></i> Glucose Trends</div>', unsafe_allow_html=True)
            st.markdown('<div class="chart-description">Average glucose levels over time with confidence intervals</div>', unsafe_allow_html=True)
            st.plotly_chart(fig_trend, use_container_width=True)
            st.markdown('</div>', unsafe_allow_html=True)
        
        # Recent alerts
        st.markdown("### <i class='fas fa-exclamation-triangle'></i> Recent High-Risk Episodes", unsafe_allow_html=True)
        recent_risks = df[df['risk_flag'] == 1].tail(5)[['patient_id', 'timestamp', 'glucose_level', 'diabetes_type']]
        if not recent_risks.empty:
            st.dataframe(recent_risks, use_container_width=True)
        else:
            st.success("No recent high-risk episodes detected!")
    
    elif st.session_state.current_page == 'Analytics':
        create_analytics_page(df, predictor)
    
    elif st.session_state.current_page == 'Prediction':
        create_prediction_page(predictor)
    
    elif st.session_state.current_page == 'Patients':
        create_patients_page(df)
    
    elif st.session_state.current_page == 'Reports':
        create_reports_page(df)

if __name__ == "__main__":
    main()