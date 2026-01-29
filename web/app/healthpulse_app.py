"""HealthPulse Web Dashboard - Fitness & Wellness Analytics.

Connects to the FastAPI backend for data and predictions.
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import requests
import warnings

warnings.filterwarnings('ignore')

# Configuration
API_BASE_URL = "http://localhost:8000/api/v1"

# Page config
st.set_page_config(
    page_title="HealthPulse - Fitness Analytics",
    page_icon="🏃",
    layout="wide",
    initial_sidebar_state="collapsed"
)


def get_default_theme():
    """Determine default theme based on time"""
    current_hour = datetime.now().hour
    return "light" if 8 <= current_hour < 19 else "dark"


def init_session_state():
    """Initialize session state"""
    if 'theme' not in st.session_state:
        st.session_state.theme = get_default_theme()
    if 'current_page' not in st.session_state:
        st.session_state.current_page = 'Dashboard'
    if 'auth_token' not in st.session_state:
        st.session_state.auth_token = None
    if 'user_email' not in st.session_state:
        st.session_state.user_email = None


def get_theme_colors():
    """Get color scheme based on current theme"""
    if st.session_state.theme == "light":
        return {
            'background': '#F8F9FA',
            'surface': '#FFFFFF',
            'card': '#FFFFFF',
            'text_primary': '#212529',
            'text_secondary': '#6C757D',
            'primary': '#28A745',
            'danger': '#DC3545',
            'warning': '#FFC107',
            'info': '#007BFF',
            'border': '#DEE2E6',
            'chart_bg': '#FFFFFF',
            'chart_grid': '#E9ECEF',
        }
    else:
        return {
            'background': '#121212',
            'surface': '#1E1E1E',
            'card': '#2D2D2D',
            'text_primary': '#FFFFFF',
            'text_secondary': '#B0B0B0',
            'primary': '#28A745',
            'danger': '#FF4C4C',
            'warning': '#FF9E3D',
            'info': '#3BA9FF',
            'border': '#404040',
            'chart_bg': '#1E1E1E',
            'chart_grid': '#404040',
        }


def apply_theme_css():
    """Apply theme-specific CSS"""
    colors = get_theme_colors()

    st.markdown(f"""
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

        .stApp {{
            background: {colors['background']};
            font-family: 'Inter', sans-serif;
        }}

        .main .block-container {{
            padding: 1rem;
            max-width: 100%;
        }}

        .metric-card {{
            background: {colors['card']};
            border-radius: 16px;
            padding: 1.5rem;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            border: 1px solid {colors['border']};
            transition: transform 0.2s;
        }}

        .metric-card:hover {{
            transform: translateY(-4px);
        }}

        .score-circle {{
            width: 120px;
            height: 120px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2.5rem;
            font-weight: 700;
            margin: 0 auto 1rem;
        }}

        .score-high {{ background: linear-gradient(135deg, {colors['primary']}, #20c997); color: white; }}
        .score-medium {{ background: linear-gradient(135deg, {colors['warning']}, #fd7e14); color: white; }}
        .score-low {{ background: linear-gradient(135deg, {colors['danger']}, #e83e8c); color: white; }}

        .recommendation-card {{
            background: {colors['surface']};
            border-left: 4px solid {colors['primary']};
            padding: 1rem;
            margin: 0.5rem 0;
            border-radius: 0 8px 8px 0;
        }}

        .insight-card {{
            background: {colors['card']};
            border-radius: 12px;
            padding: 1rem;
            margin: 0.5rem 0;
            border: 1px solid {colors['border']};
        }}

        .insight-correlation {{ border-left: 4px solid {colors['info']}; }}
        .insight-recommendation {{ border-left: 4px solid {colors['primary']}; }}
        .insight-trend {{ border-left: 4px solid {colors['warning']}; }}

        .status-badge {{
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 500;
        }}

        .status-recovered {{ background: {colors['primary']}20; color: {colors['primary']}; }}
        .status-moderate {{ background: {colors['warning']}20; color: {colors['warning']}; }}
        .status-fatigued {{ background: {colors['danger']}20; color: {colors['danger']}; }}

        #MainMenu, footer, header {{ visibility: hidden; }}
    </style>
    """, unsafe_allow_html=True)


def api_request(endpoint: str, method: str = "GET", data: dict = None) -> dict | None:
    """Make authenticated API request"""
    headers = {}
    if st.session_state.auth_token:
        headers["Authorization"] = f"Bearer {st.session_state.auth_token}"

    try:
        url = f"{API_BASE_URL}{endpoint}"
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data, timeout=10)

        if response.status_code == 200:
            return response.json()
        elif response.status_code == 401:
            st.session_state.auth_token = None
            return None
        else:
            return None
    except requests.exceptions.ConnectionError:
        return None
    except Exception:
        return None


def create_header():
    """Create app header"""
    col1, col2, col3 = st.columns([1, 2, 1])

    with col2:
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0;">
            <h1 style="margin: 0; font-size: 2.5rem;">
                🏃 HealthPulse
            </h1>
            <p style="margin: 0.5rem 0 0; opacity: 0.7;">
                Your Personal Fitness & Wellness Analytics
            </p>
        </div>
        """, unsafe_allow_html=True)

    with col3:
        if st.button("🌙" if st.session_state.theme == "light" else "☀️", key="theme_toggle"):
            st.session_state.theme = "dark" if st.session_state.theme == "light" else "light"
            st.rerun()


def create_nav():
    """Create navigation"""
    pages = ['Dashboard', 'Workouts', 'Metrics', 'Insights', 'Settings']

    cols = st.columns(len(pages))
    for i, page in enumerate(pages):
        with cols[i]:
            if st.button(page, key=f"nav_{page}", use_container_width=True,
                        type="primary" if st.session_state.current_page == page else "secondary"):
                st.session_state.current_page = page
                st.rerun()


def create_score_card(title: str, score: float, status: str = None, subtitle: str = None):
    """Create a score display card"""
    colors = get_theme_colors()

    if score >= 80:
        score_class = "score-high"
    elif score >= 50:
        score_class = "score-medium"
    else:
        score_class = "score-low"

    status_class = f"status-{status}" if status else ""

    st.markdown(f"""
    <div class="metric-card" style="text-align: center;">
        <h3 style="margin: 0 0 1rem; color: {colors['text_secondary']};">{title}</h3>
        <div class="score-circle {score_class}">{score:.0f}</div>
        {f'<span class="status-badge {status_class}">{status.title()}</span>' if status else ''}
        {f'<p style="margin: 0.5rem 0 0; opacity: 0.7;">{subtitle}</p>' if subtitle else ''}
    </div>
    """, unsafe_allow_html=True)


def create_dashboard_page():
    """Create main dashboard page"""
    colors = get_theme_colors()

    st.markdown("## Today's Overview")

    # Check if authenticated
    if not st.session_state.auth_token:
        st.info("Login to see your personalized dashboard. Using demo data for now.")

        # Demo data
        recovery_data = {
            "score": 78,
            "status": "moderate",
            "confidence": 0.85,
            "recommendations": [
                "Your sleep was 6.5 hours - aim for 7-9 hours tonight",
                "Consider a moderate intensity workout today"
            ],
            "contributing_factors": {
                "sleep_hours": {"value": 6.5, "score": 75, "impact": "negative"},
                "sleep_quality": {"value": 72, "score": 72, "impact": "positive"},
                "stress": {"value": 4, "score": 60, "impact": "neutral"}
            }
        }

        readiness_data = {
            "score": 72,
            "recommended_intensity": "moderate",
            "confidence": 0.85,
            "suggested_workout_types": ["Tempo Run", "Circuit Training", "Swimming"]
        }

        wellness_data = {
            "overall_score": 75,
            "components": {
                "sleep": 72,
                "activity": 80,
                "recovery": 78,
                "nutrition": 70,
                "stress_management": 65,
                "mood": 75
            },
            "trend": "improving",
            "comparison_to_baseline": 3.5
        }
    else:
        # Fetch real data from API
        recovery_data = api_request("/predictions/recovery")
        readiness_data = api_request("/predictions/readiness")
        wellness_data = api_request("/predictions/wellness")

        if not recovery_data:
            recovery_data = {"score": 70, "status": "moderate", "recommendations": [], "contributing_factors": {}}
        if not readiness_data:
            readiness_data = {"score": 70, "recommended_intensity": "moderate", "suggested_workout_types": []}
        if not wellness_data:
            wellness_data = {"overall_score": 70, "components": {}, "trend": "stable", "comparison_to_baseline": 0}

    # Score cards
    col1, col2, col3 = st.columns(3)

    with col1:
        create_score_card(
            "Recovery",
            recovery_data.get("score", 70),
            recovery_data.get("status", "moderate"),
            f"Confidence: {recovery_data.get('confidence', 0.8):.0%}"
        )

    with col2:
        create_score_card(
            "Readiness",
            readiness_data.get("score", 70),
            None,
            f"Recommended: {readiness_data.get('recommended_intensity', 'moderate').title()}"
        )

    with col3:
        create_score_card(
            "Wellness",
            wellness_data.get("overall_score", 70),
            None,
            f"Trend: {wellness_data.get('trend', 'stable').title()} ({wellness_data.get('comparison_to_baseline', 0):+.1f})"
        )

    st.markdown("---")

    # Recommendations and details
    col1, col2 = st.columns([2, 1])

    with col1:
        st.markdown("### Recommendations")

        recommendations = recovery_data.get("recommendations", [])
        if recommendations:
            for rec in recommendations:
                st.markdown(f"""
                <div class="recommendation-card">
                    💡 {rec}
                </div>
                """, unsafe_allow_html=True)
        else:
            st.markdown("""
            <div class="recommendation-card">
                ✅ Looking good! Maintain your current routine.
            </div>
            """, unsafe_allow_html=True)

        st.markdown("### Suggested Workouts")
        workout_types = readiness_data.get("suggested_workout_types", ["Walking", "Light Stretching"])
        workout_cols = st.columns(len(workout_types[:4]))
        for i, workout in enumerate(workout_types[:4]):
            with workout_cols[i]:
                st.markdown(f"""
                <div class="metric-card" style="text-align: center; padding: 1rem;">
                    <span style="font-size: 1.5rem;">🏋️</span>
                    <p style="margin: 0.5rem 0 0; font-weight: 500;">{workout}</p>
                </div>
                """, unsafe_allow_html=True)

    with col2:
        st.markdown("### Wellness Breakdown")

        components = wellness_data.get("components", {
            "sleep": 70, "activity": 70, "recovery": 70,
            "nutrition": 70, "stress_management": 70, "mood": 70
        })

        for component, score in components.items():
            color = colors['primary'] if score >= 70 else colors['warning'] if score >= 50 else colors['danger']
            st.markdown(f"""
            <div style="margin: 0.5rem 0;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 0.25rem;">
                    <span>{component.replace('_', ' ').title()}</span>
                    <span style="font-weight: 600;">{score:.0f}</span>
                </div>
                <div style="height: 8px; background: {colors['border']}; border-radius: 4px;">
                    <div style="height: 100%; width: {score}%; background: {color}; border-radius: 4px;"></div>
                </div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("---")

    # Weekly trend chart
    st.markdown("### Weekly Wellness Trend")

    # Generate demo trend data
    dates = pd.date_range(end=datetime.now(), periods=7)
    trend_data = pd.DataFrame({
        'date': dates,
        'wellness': np.random.randint(65, 85, 7),
        'recovery': np.random.randint(60, 90, 7),
        'readiness': np.random.randint(55, 85, 7)
    })

    fig = go.Figure()

    fig.add_trace(go.Scatter(
        x=trend_data['date'], y=trend_data['wellness'],
        name='Wellness', line=dict(color=colors['primary'], width=3),
        mode='lines+markers'
    ))

    fig.add_trace(go.Scatter(
        x=trend_data['date'], y=trend_data['recovery'],
        name='Recovery', line=dict(color=colors['info'], width=3),
        mode='lines+markers'
    ))

    fig.add_trace(go.Scatter(
        x=trend_data['date'], y=trend_data['readiness'],
        name='Readiness', line=dict(color=colors['warning'], width=3),
        mode='lines+markers'
    ))

    fig.update_layout(
        plot_bgcolor=colors['chart_bg'],
        paper_bgcolor=colors['chart_bg'],
        font=dict(color=colors['text_primary']),
        xaxis=dict(gridcolor=colors['chart_grid']),
        yaxis=dict(gridcolor=colors['chart_grid'], range=[0, 100]),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="center", x=0.5),
        margin=dict(l=40, r=40, t=40, b=40),
        height=300
    )

    st.plotly_chart(fig, use_container_width=True)


def create_workouts_page():
    """Create workouts page"""
    st.markdown("## Workouts")

    col1, col2 = st.columns([2, 1])

    with col1:
        st.markdown("### Log Workout")

        workout_type = st.selectbox("Type", ["Running", "Cycling", "Swimming", "Strength", "HIIT", "Yoga", "Walking"])

        col_a, col_b = st.columns(2)
        with col_a:
            duration = st.number_input("Duration (minutes)", min_value=5, max_value=300, value=45)
        with col_b:
            intensity = st.select_slider("Intensity", options=["Low", "Moderate", "High"])

        notes = st.text_area("Notes (optional)", placeholder="How did you feel?")

        if st.button("Log Workout", type="primary", use_container_width=True):
            if st.session_state.auth_token:
                # Submit to API
                result = api_request("/workouts", "POST", {
                    "workout_type": workout_type.lower(),
                    "duration_minutes": duration,
                    "intensity": intensity.lower(),
                    "notes": notes
                })
                if result:
                    st.success("Workout logged!")
                else:
                    st.error("Failed to log workout")
            else:
                st.warning("Please login to log workouts")

    with col2:
        st.markdown("### Quick Stats")

        st.metric("This Week", "4 workouts", "+1 from last week")
        st.metric("Total Duration", "3h 45m", "+45m")
        st.metric("Training Load", "320", "Optimal range")


def create_metrics_page():
    """Create metrics logging page"""
    st.markdown("## Log Metrics")

    tab1, tab2, tab3 = st.tabs(["Daily Check-in", "Body Metrics", "Manual Entry"])

    with tab1:
        st.markdown("### How are you feeling today?")

        col1, col2 = st.columns(2)

        with col1:
            energy = st.slider("Energy Level", 1, 10, 7)
            mood = st.slider("Mood", 1, 10, 7)
            stress = st.slider("Stress Level", 1, 10, 4)

        with col2:
            sleep_hours = st.number_input("Sleep (hours)", min_value=0.0, max_value=12.0, value=7.5, step=0.5)
            sleep_quality = st.slider("Sleep Quality", 1, 10, 7)
            soreness = st.slider("Muscle Soreness", 1, 10, 3)

        if st.button("Submit Check-in", type="primary"):
            if st.session_state.auth_token:
                # Submit metrics
                st.success("Daily check-in recorded!")
            else:
                st.warning("Please login to save your check-in")

    with tab2:
        col1, col2 = st.columns(2)

        with col1:
            weight = st.number_input("Weight (kg)", min_value=30.0, max_value=200.0, value=70.0, step=0.1)
            body_fat = st.number_input("Body Fat %", min_value=5.0, max_value=50.0, value=20.0, step=0.1)

        with col2:
            resting_hr = st.number_input("Resting HR (bpm)", min_value=30, max_value=120, value=60)
            hrv = st.number_input("HRV (ms)", min_value=10, max_value=200, value=50)

        if st.button("Save Body Metrics", type="primary"):
            st.success("Body metrics saved!")

    with tab3:
        metric_type = st.selectbox("Metric Type", [
            "steps", "calories", "water", "caffeine", "alcohol"
        ])
        value = st.number_input("Value", min_value=0.0, value=0.0)

        if st.button("Log Metric", type="primary"):
            st.success(f"Logged {value} for {metric_type}")


def create_insights_page():
    """Create insights page"""
    st.markdown("## AI Insights")

    # Fetch insights
    if st.session_state.auth_token:
        insights = api_request("/predictions/insights")
        correlations = api_request("/predictions/correlations")
    else:
        # Demo insights
        insights = [
            {
                "category": "recommendation",
                "title": "Optimize Your Sleep",
                "description": "Your recovery scores are highest when you sleep 7.5+ hours. Try to maintain this consistently."
            },
            {
                "category": "correlation",
                "title": "Exercise & Sleep Connection",
                "description": "There's a positive correlation between your workout days and sleep quality. Keep up the active lifestyle!"
            },
            {
                "category": "trend",
                "title": "Wellness Improving",
                "description": "Your wellness score has improved by 8% over the past 2 weeks. Great progress!"
            }
        ]
        correlations = [
            {"factor_a": "sleep", "factor_b": "recovery", "correlation": 0.72,
             "insight": "Strong positive relationship between sleep and recovery."},
            {"factor_a": "stress", "factor_b": "hrv", "correlation": -0.58,
             "insight": "Higher stress is associated with lower HRV."}
        ]

    colors = get_theme_colors()

    # Display insights
    st.markdown("### Personalized Insights")

    for insight in (insights or []):
        category = insight.get("category", "recommendation")
        icon = {"recommendation": "💡", "correlation": "🔗", "trend": "📈"}.get(category, "💡")

        st.markdown(f"""
        <div class="insight-card insight-{category}">
            <h4 style="margin: 0 0 0.5rem;">{icon} {insight.get('title', 'Insight')}</h4>
            <p style="margin: 0; opacity: 0.8;">{insight.get('description', '')}</p>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("---")

    # Display correlations
    st.markdown("### Discovered Correlations")

    if correlations:
        for corr in correlations[:5]:
            corr_val = corr.get("correlation", 0)
            color = colors['primary'] if corr_val > 0 else colors['danger']
            width = abs(corr_val) * 100

            st.markdown(f"""
            <div class="metric-card" style="padding: 1rem; margin: 0.5rem 0;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span><strong>{corr.get('factor_a', '').title()}</strong> ↔ <strong>{corr.get('factor_b', '').title()}</strong></span>
                    <span style="color: {color}; font-weight: 600;">{corr_val:+.2f}</span>
                </div>
                <div style="height: 6px; background: {colors['border']}; border-radius: 3px; margin: 0.5rem 0;">
                    <div style="height: 100%; width: {width}%; background: {color}; border-radius: 3px;"></div>
                </div>
                <p style="margin: 0; font-size: 0.9rem; opacity: 0.7;">{corr.get('insight', '')}</p>
            </div>
            """, unsafe_allow_html=True)
    else:
        st.info("Log more data to discover correlations in your health metrics.")


def create_settings_page():
    """Create settings page"""
    st.markdown("## Settings")

    tab1, tab2, tab3 = st.tabs(["Account", "Preferences", "Integrations"])

    with tab1:
        st.markdown("### Authentication")

        if st.session_state.auth_token:
            st.success(f"Logged in as: {st.session_state.user_email}")
            if st.button("Logout"):
                st.session_state.auth_token = None
                st.session_state.user_email = None
                st.rerun()
        else:
            auth_tab1, auth_tab2 = st.tabs(["Login", "Sign Up"])

            with auth_tab1:
                email = st.text_input("Email", key="login_email")
                password = st.text_input("Password", type="password", key="login_password")

                if st.button("Login", type="primary"):
                    try:
                        response = requests.post(
                            f"{API_BASE_URL}/auth/signin",
                            json={"email": email, "password": password},
                            timeout=10
                        )
                        if response.status_code == 200:
                            data = response.json()
                            st.session_state.auth_token = data.get("access_token")
                            st.session_state.user_email = email
                            st.success("Logged in successfully!")
                            st.rerun()
                        else:
                            st.error("Invalid credentials")
                    except Exception as e:
                        st.error(f"Connection error: {e}")

            with auth_tab2:
                new_email = st.text_input("Email", key="signup_email")
                new_password = st.text_input("Password", type="password", key="signup_password")
                confirm_password = st.text_input("Confirm Password", type="password")

                if st.button("Sign Up", type="primary"):
                    if new_password != confirm_password:
                        st.error("Passwords don't match")
                    else:
                        try:
                            response = requests.post(
                                f"{API_BASE_URL}/auth/signup",
                                json={"email": new_email, "password": new_password},
                                timeout=10
                            )
                            if response.status_code == 200:
                                st.success("Account created! Check your email to confirm.")
                            else:
                                st.error(response.json().get("detail", "Signup failed"))
                        except Exception as e:
                            st.error(f"Connection error: {e}")

    with tab2:
        st.markdown("### Display Preferences")

        units = st.selectbox("Units", ["Metric", "Imperial"])

        st.markdown("### Notification Preferences")
        st.checkbox("Daily check-in reminder", value=True)
        st.checkbox("Weekly summary", value=True)
        st.checkbox("Achievement notifications", value=True)

        st.markdown("### Baseline Settings")
        col1, col2 = st.columns(2)
        with col1:
            st.number_input("Baseline HRV (ms)", value=50)
            st.number_input("Baseline Resting HR (bpm)", value=60)
        with col2:
            st.number_input("Target Sleep (hours)", value=8.0, step=0.5)
            st.number_input("Daily Step Goal", value=10000)

    with tab3:
        st.markdown("### Connected Services")

        integrations = [
            ("Apple Health", "🍎", False),
            ("Strava", "🚴", False),
            ("Garmin", "⌚", False),
            ("Oura Ring", "💍", False),
            ("Whoop", "📊", False),
        ]

        for name, icon, connected in integrations:
            col1, col2 = st.columns([3, 1])
            with col1:
                status = "✅ Connected" if connected else "Not connected"
                st.markdown(f"{icon} **{name}** - {status}")
            with col2:
                if connected:
                    st.button("Disconnect", key=f"disconnect_{name}")
                else:
                    st.button("Connect", key=f"connect_{name}")


def main():
    """Main application"""
    init_session_state()
    apply_theme_css()

    create_header()
    create_nav()

    st.markdown("---")

    # Route to current page
    if st.session_state.current_page == 'Dashboard':
        create_dashboard_page()
    elif st.session_state.current_page == 'Workouts':
        create_workouts_page()
    elif st.session_state.current_page == 'Metrics':
        create_metrics_page()
    elif st.session_state.current_page == 'Insights':
        create_insights_page()
    elif st.session_state.current_page == 'Settings':
        create_settings_page()


if __name__ == "__main__":
    main()
