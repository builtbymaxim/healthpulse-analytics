"""HealthPulse Web Dashboard - Clean, Modern Design."""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import requests

# Configuration
API_BASE_URL = "http://localhost:8000/api/v1"

st.set_page_config(
    page_title="HealthPulse",
    page_icon="HP",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Clean CSS styling
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

    .stApp {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    }

    .main .block-container {
        padding: 2rem 3rem;
        max-width: 1400px;
    }

    /* Header */
    .header {
        padding: 1.5rem 0 2rem;
        border-bottom: 1px solid rgba(128,128,128,0.2);
        margin-bottom: 2rem;
    }

    .header h1 {
        font-size: 1.75rem;
        font-weight: 600;
        margin: 0;
        color: inherit;
    }

    .header p {
        color: #888;
        margin: 0.25rem 0 0;
        font-size: 0.9rem;
    }

    /* Metric Cards */
    .metric-container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1.5rem;
        margin-bottom: 2rem;
    }

    .metric-card {
        background: rgba(128,128,128,0.05);
        border: 1px solid rgba(128,128,128,0.15);
        border-radius: 12px;
        padding: 1.5rem;
        transition: all 0.2s ease;
    }

    .metric-card:hover {
        border-color: rgba(128,128,128,0.3);
        transform: translateY(-2px);
    }

    .metric-label {
        font-size: 0.8rem;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: #888;
        margin-bottom: 0.5rem;
    }

    .metric-value {
        font-size: 2.25rem;
        font-weight: 700;
        line-height: 1.2;
    }

    .metric-sub {
        font-size: 0.85rem;
        color: #888;
        margin-top: 0.5rem;
    }

    .metric-good { color: #22c55e; }
    .metric-warning { color: #f59e0b; }
    .metric-danger { color: #ef4444; }
    .metric-neutral { color: inherit; }

    /* Section headers */
    .section-header {
        font-size: 1.1rem;
        font-weight: 600;
        margin: 2rem 0 1rem;
        padding-bottom: 0.5rem;
        border-bottom: 1px solid rgba(128,128,128,0.2);
    }

    /* Data tables */
    .clean-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.9rem;
    }

    .clean-table th {
        text-align: left;
        padding: 0.75rem 1rem;
        font-weight: 500;
        color: #888;
        border-bottom: 1px solid rgba(128,128,128,0.2);
    }

    .clean-table td {
        padding: 0.75rem 1rem;
        border-bottom: 1px solid rgba(128,128,128,0.1);
    }

    /* Status badges */
    .badge {
        display: inline-block;
        padding: 0.25rem 0.75rem;
        border-radius: 100px;
        font-size: 0.75rem;
        font-weight: 500;
    }

    .badge-good {
        background: rgba(34, 197, 94, 0.15);
        color: #22c55e;
    }

    .badge-warning {
        background: rgba(245, 158, 11, 0.15);
        color: #f59e0b;
    }

    .badge-danger {
        background: rgba(239, 68, 68, 0.15);
        color: #ef4444;
    }

    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}

    /* Clean up default Streamlit styling */
    .stTabs [data-baseweb="tab-list"] {
        gap: 2rem;
        border-bottom: 1px solid rgba(128,128,128,0.2);
    }

    .stTabs [data-baseweb="tab"] {
        padding: 0.75rem 0;
        font-weight: 500;
    }

    .stMetric {
        background: rgba(128,128,128,0.05);
        border: 1px solid rgba(128,128,128,0.15);
        border-radius: 12px;
        padding: 1rem;
    }

    .stMetric label {
        font-size: 0.8rem !important;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    div[data-testid="stMetricValue"] {
        font-size: 2rem !important;
        font-weight: 700 !important;
    }
</style>
""", unsafe_allow_html=True)


def init_session_state():
    """Initialize session state variables."""
    defaults = {
        'auth_token': None,
        'user_email': None,
        'current_page': 'Dashboard',
        'show_login': True
    }
    for key, value in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = value


def api_request(endpoint: str, method: str = "GET", data: dict = None):
    """Make API request to backend."""
    try:
        headers = {"Content-Type": "application/json"}
        if st.session_state.auth_token:
            headers["Authorization"] = f"Bearer {st.session_state.auth_token}"

        url = f"{API_BASE_URL}{endpoint}"

        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, json=data, headers=headers, timeout=10)
        elif method == "PUT":
            response = requests.put(url, json=data, headers=headers, timeout=10)

        if response.status_code in [200, 201]:
            return {"success": True, "data": response.json()}
        else:
            error_msg = response.json().get("detail", "Request failed")
            return {"success": False, "error": error_msg}
    except requests.exceptions.ConnectionError:
        return {"success": False, "error": "Cannot connect to server"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def sign_in(email: str, password: str):
    """Sign in user via backend API."""
    result = api_request("/auth/signin", "POST", {"email": email, "password": password})
    if result and result.get("success"):
        data = result["data"]
        st.session_state.auth_token = data.get("access_token")
        st.session_state.user_email = data.get("email", email)
        return True, None
    return False, result.get("error", "Sign in failed") if result else "Connection error"


def sign_up(email: str, password: str):
    """Sign up user via backend API."""
    result = api_request("/auth/signup", "POST", {"email": email, "password": password})
    if result and result.get("success"):
        data = result["data"]
        if data.get("requires_confirmation"):
            return False, "Check your email for confirmation link"
        st.session_state.auth_token = data.get("access_token")
        st.session_state.user_email = data.get("email", email)
        return True, None
    return False, result.get("error", "Sign up failed") if result else "Connection error"


def get_live_data():
    """Fetch real data from backend API."""
    data = {
        "recovery": None,
        "readiness": None,
        "wellness": None,
        "sleep_hours": None,
        "resting_hr": None,
        "hrv": None,
        "steps": None,
        "calories": None,
        "weekly_dates": [],
        "weekly_recovery": [],
        "weekly_sleep": [],
        "weekly_steps": [],
        "workouts": [],
        "insights": [],
        "correlations": [],
        # Nutrition data
        "nutrition_summary": None,
        "nutrition_goal": None,
        "physical_profile": None,
        "food_entries": []
    }

    # Fetch predictions
    recovery = api_request("/predictions/recovery")
    if recovery and recovery.get("success"):
        data["recovery"] = recovery["data"].get("recovery_score")

    readiness = api_request("/predictions/readiness")
    if readiness and readiness.get("success"):
        data["readiness"] = readiness["data"].get("readiness_score")

    wellness = api_request("/predictions/wellness")
    if wellness and wellness.get("success"):
        w_data = wellness["data"]
        data["wellness"] = w_data.get("wellness_score")
        data["sleep_hours"] = w_data.get("sleep_hours")
        data["resting_hr"] = w_data.get("resting_hr")
        data["hrv"] = w_data.get("hrv")
        data["steps"] = w_data.get("steps")
        data["calories"] = w_data.get("calories_in")

    # Fetch wellness history for charts
    history = api_request("/predictions/wellness/history?days=7")
    if history and history.get("success"):
        for item in history["data"]:
            date_str = item.get("date", "")
            if date_str:
                try:
                    dt = datetime.fromisoformat(date_str.replace("Z", ""))
                    data["weekly_dates"].append(dt.strftime("%a"))
                except:
                    data["weekly_dates"].append(date_str[:3])
            data["weekly_recovery"].append(item.get("wellness_score", 0))
            data["weekly_sleep"].append(item.get("sleep_hours", 0))
            data["weekly_steps"].append(item.get("steps", 0))

    # Fetch workouts
    workouts = api_request("/workouts?days=30")
    if workouts and workouts.get("success"):
        for w in workouts["data"][:10]:
            start_time = w.get("start_time", "")
            try:
                dt = datetime.fromisoformat(start_time.replace("Z", ""))
                days_ago = (datetime.now() - dt).days
                if days_ago == 0:
                    date_display = "Today"
                elif days_ago == 1:
                    date_display = "Yesterday"
                else:
                    date_display = f"{days_ago} days ago"
            except:
                date_display = start_time[:10]

            data["workouts"].append({
                "date": date_display,
                "type": w.get("workout_type", "").replace("_", " ").title(),
                "duration": w.get("duration_minutes", 0),
                "intensity": w.get("intensity", "moderate").title()
            })

    # Fetch insights
    insights = api_request("/predictions/insights?limit=5")
    if insights and insights.get("success"):
        data["insights"] = insights["data"]

    # Fetch correlations
    correlations = api_request("/predictions/correlations")
    if correlations and correlations.get("success"):
        data["correlations"] = correlations["data"]

    # Fetch nutrition data
    nutrition_summary = api_request("/nutrition/summary")
    if nutrition_summary and nutrition_summary.get("success"):
        data["nutrition_summary"] = nutrition_summary["data"]

    nutrition_goal = api_request("/nutrition/goals")
    if nutrition_goal and nutrition_goal.get("success"):
        data["nutrition_goal"] = nutrition_goal["data"]

    physical_profile = api_request("/nutrition/physical-profile")
    if physical_profile and physical_profile.get("success"):
        data["physical_profile"] = physical_profile["data"]

    food_entries = api_request("/nutrition/food")
    if food_entries and food_entries.get("success"):
        data["food_entries"] = food_entries["data"]

    return data


def get_demo_data():
    """Generate demo data for display."""
    np.random.seed(42)
    today = datetime.now()

    # Weekly metrics
    dates = [(today - timedelta(days=i)).strftime("%a") for i in range(6, -1, -1)]

    return {
        "recovery": 78,
        "readiness": 82,
        "wellness": 75,
        "sleep_hours": 7.2,
        "resting_hr": 58,
        "hrv": 45,
        "steps": 8432,
        "calories": 2150,
        "weekly_dates": dates,
        "weekly_recovery": [72, 68, 75, 80, 78, 82, 78],
        "weekly_sleep": [6.5, 7.0, 7.5, 8.0, 7.2, 6.8, 7.2],
        "weekly_steps": [6500, 8200, 7800, 9500, 8432, 7200, 8432],
        "workouts": [
            {"date": "Today", "type": "Running", "duration": 45, "intensity": "Moderate"},
            {"date": "Yesterday", "type": "Strength", "duration": 60, "intensity": "High"},
            {"date": "2 days ago", "type": "Cycling", "duration": 30, "intensity": "Low"},
        ],
        # Demo nutrition data
        "nutrition_summary": {
            "date": today.strftime("%Y-%m-%d"),
            "total_calories": 1650,
            "total_protein_g": 95,
            "total_carbs_g": 180,
            "total_fat_g": 55,
            "calorie_target": 2200,
            "protein_target_g": 165,
            "carbs_target_g": 248,
            "fat_target_g": 61,
            "calorie_progress_pct": 75,
            "protein_progress_pct": 58,
            "carbs_progress_pct": 73,
            "fat_progress_pct": 90,
            "calories_remaining": 550,
            "nutrition_score": 72
        },
        "nutrition_goal": {
            "goal_type": "build_muscle",
            "bmr": 1750,
            "tdee": 2713,
            "calorie_target": 2200,
            "protein_target_g": 165,
            "carbs_target_g": 248,
            "fat_target_g": 61
        },
        "physical_profile": {
            "age": 30,
            "height_cm": 178,
            "gender": "male",
            "activity_level": "moderate",
            "latest_weight_kg": 75,
            "profile_complete": True
        },
        "food_entries": [
            {"name": "Oatmeal with Berries", "meal_type": "breakfast", "calories": 350, "protein_g": 12, "carbs_g": 55, "fat_g": 8},
            {"name": "Grilled Chicken Salad", "meal_type": "lunch", "calories": 550, "protein_g": 45, "carbs_g": 25, "fat_g": 28},
            {"name": "Protein Shake", "meal_type": "snack", "calories": 250, "protein_g": 30, "carbs_g": 15, "fat_g": 5},
            {"name": "Salmon with Rice", "meal_type": "dinner", "calories": 500, "protein_g": 38, "carbs_g": 45, "fat_g": 14},
        ]
    }


def render_auth():
    """Render login/signup form."""
    st.markdown("""
        <div class="header">
            <h1>HealthPulse</h1>
            <p>Sign in to access your wellness dashboard</p>
        </div>
    """, unsafe_allow_html=True)

    col1, col2, col3 = st.columns([1, 2, 1])

    with col2:
        tab_login, tab_signup = st.tabs(["Sign In", "Sign Up"])

        with tab_login:
            with st.form("login_form"):
                email = st.text_input("Email", key="login_email")
                password = st.text_input("Password", type="password", key="login_password")
                submitted = st.form_submit_button("Sign In", type="primary", use_container_width=True)

                if submitted:
                    if email and password:
                        success, error = sign_in(email, password)
                        if success:
                            st.rerun()
                        else:
                            st.error(error)
                    else:
                        st.warning("Please enter email and password")

        with tab_signup:
            with st.form("signup_form"):
                email = st.text_input("Email", key="signup_email")
                password = st.text_input("Password", type="password", key="signup_password")
                password_confirm = st.text_input("Confirm Password", type="password", key="signup_password_confirm")
                submitted = st.form_submit_button("Create Account", type="primary", use_container_width=True)

                if submitted:
                    if not email or not password:
                        st.warning("Please enter email and password")
                    elif password != password_confirm:
                        st.error("Passwords do not match")
                    elif len(password) < 6:
                        st.error("Password must be at least 6 characters")
                    else:
                        success, error = sign_up(email, password)
                        if success:
                            st.rerun()
                        elif error:
                            st.info(error) if "email" in error.lower() else st.error(error)


def render_header():
    """Render page header."""
    user_info = f" - {st.session_state.user_email}" if st.session_state.user_email else ""
    st.markdown(f"""
        <div class="header">
            <h1>HealthPulse</h1>
            <p>Your fitness and wellness dashboard{user_info}</p>
        </div>
    """, unsafe_allow_html=True)


def render_metric_card(label: str, value: str, sub: str = None, status: str = "neutral"):
    """Render a single metric card."""
    status_class = f"metric-{status}"
    sub_html = f'<div class="metric-sub">{sub}</div>' if sub else ''

    return f"""
        <div class="metric-card">
            <div class="metric-label">{label}</div>
            <div class="metric-value {status_class}">{value}</div>
            {sub_html}
        </div>
    """


def get_status(value: float, good_threshold: float = 75, warning_threshold: float = 50):
    """Determine status based on value."""
    if value >= good_threshold:
        return "good"
    elif value >= warning_threshold:
        return "warning"
    return "danger"


def render_dashboard():
    """Render main dashboard."""
    # Use live data if authenticated, otherwise demo
    if st.session_state.auth_token:
        data = get_live_data()
        using_live = True
    else:
        data = get_demo_data()
        using_live = False

    # Main metrics row
    cols = st.columns(4)

    recovery = data.get("recovery") or 0
    readiness = data.get("readiness") or 0
    wellness = data.get("wellness") or 0
    sleep_hours = data.get("sleep_hours") or 0

    with cols[0]:
        delta_text = "Based on recent data" if using_live else "Moderate intensity recommended"
        st.metric(
            label="Recovery Score",
            value=f"{recovery:.0f}%" if recovery else "—",
            delta=delta_text if recovery else "No data"
        )

    with cols[1]:
        delta_text = "Based on recent data" if using_live else "Ready for training"
        st.metric(
            label="Readiness Score",
            value=f"{readiness:.0f}%" if readiness else "—",
            delta=delta_text if readiness else "No data"
        )

    with cols[2]:
        delta_text = "Based on recent data" if using_live else "+3 from last week"
        st.metric(
            label="Wellness Score",
            value=f"{wellness:.0f}%" if wellness else "—",
            delta=delta_text if wellness else "No data"
        )

    with cols[3]:
        st.metric(
            label="Sleep",
            value=f"{sleep_hours:.1f}h" if sleep_hours else "—",
            delta="Within target range" if sleep_hours else "No data"
        )

    st.markdown("<br>", unsafe_allow_html=True)

    # Charts row
    col1, col2 = st.columns(2)

    with col1:
        st.markdown("**Recovery Trend**")
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=data["weekly_dates"],
            y=data["weekly_recovery"],
            mode='lines+markers',
            line=dict(color='#22c55e', width=2),
            marker=dict(size=8),
            fill='tozeroy',
            fillcolor='rgba(34, 197, 94, 0.1)'
        ))
        fig.update_layout(
            height=250,
            margin=dict(l=0, r=0, t=20, b=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.1)', range=[0, 100]),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.markdown("**Sleep Trend**")
        fig = go.Figure()
        fig.add_trace(go.Bar(
            x=data["weekly_dates"],
            y=data["weekly_sleep"],
            marker_color='#6366f1'
        ))
        fig.update_layout(
            height=250,
            margin=dict(l=0, r=0, t=20, b=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.1)', range=[0, 10]),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)

    # Vitals row
    st.markdown("**Today's Vitals**")

    resting_hr = data.get("resting_hr")
    hrv = data.get("hrv")
    steps = data.get("steps")
    calories = data.get("calories")

    vitals_cols = st.columns(4)
    with vitals_cols[0]:
        st.metric("Resting HR", f"{resting_hr} bpm" if resting_hr else "—")
    with vitals_cols[1]:
        st.metric("HRV", f"{hrv} ms" if hrv else "—")
    with vitals_cols[2]:
        st.metric("Steps", f"{steps:,}" if steps else "—")
    with vitals_cols[3]:
        st.metric("Calories", f"{calories:,}" if calories else "—")


def render_workouts():
    """Render workouts page."""
    if st.session_state.auth_token:
        data = get_live_data()
    else:
        data = get_demo_data()

    st.markdown("**Recent Workouts**")

    # Create a clean dataframe
    workouts = data.get("workouts", [])
    if not workouts:
        workouts = [{"date": "—", "type": "No workouts", "duration": 0, "intensity": "—"}]
    df = pd.DataFrame(workouts)

    # Style the dataframe
    st.dataframe(
        df,
        use_container_width=True,
        hide_index=True,
        column_config={
            "date": st.column_config.TextColumn("Date"),
            "type": st.column_config.TextColumn("Type"),
            "duration": st.column_config.NumberColumn("Duration", format="%d min"),
            "intensity": st.column_config.TextColumn("Intensity")
        }
    )

    st.markdown("<br>", unsafe_allow_html=True)

    # Log workout form
    st.markdown("**Log New Workout**")

    col1, col2, col3 = st.columns(3)

    with col1:
        workout_type = st.selectbox(
            "Type",
            ["Running", "Cycling", "Swimming", "Strength", "Yoga", "Other"]
        )

    with col2:
        duration = st.number_input("Duration (minutes)", min_value=1, max_value=300, value=30)

    with col3:
        intensity = st.selectbox("Intensity", ["Low", "Moderate", "High"])

    if st.button("Save Workout", type="primary"):
        st.success("Workout logged successfully")


def render_metrics():
    """Render metrics/trends page."""
    data = get_demo_data()

    # Metric selection
    metric = st.selectbox(
        "Select Metric",
        ["Steps", "Sleep", "Heart Rate", "Recovery"]
    )

    # Generate chart based on selection
    if metric == "Steps":
        fig = go.Figure()
        fig.add_trace(go.Bar(
            x=data["weekly_dates"],
            y=data["weekly_steps"],
            marker_color='#3b82f6'
        ))
        fig.update_layout(
            height=350,
            margin=dict(l=0, r=0, t=20, b=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.1)'),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)

        # Stats
        cols = st.columns(3)
        with cols[0]:
            st.metric("Average", f"{int(np.mean(data['weekly_steps'])):,}")
        with cols[1]:
            st.metric("Best Day", f"{max(data['weekly_steps']):,}")
        with cols[2]:
            st.metric("Total", f"{sum(data['weekly_steps']):,}")

    elif metric == "Sleep":
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=data["weekly_dates"],
            y=data["weekly_sleep"],
            mode='lines+markers',
            line=dict(color='#8b5cf6', width=2),
            marker=dict(size=8),
            fill='tozeroy',
            fillcolor='rgba(139, 92, 246, 0.1)'
        ))
        fig.update_layout(
            height=350,
            margin=dict(l=0, r=0, t=20, b=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.1)', range=[0, 10]),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)

        cols = st.columns(3)
        with cols[0]:
            st.metric("Average", f"{np.mean(data['weekly_sleep']):.1f}h")
        with cols[1]:
            st.metric("Best Night", f"{max(data['weekly_sleep'])}h")
        with cols[2]:
            st.metric("Goal Progress", "85%")

    elif metric == "Recovery":
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=data["weekly_dates"],
            y=data["weekly_recovery"],
            mode='lines+markers',
            line=dict(color='#22c55e', width=2),
            marker=dict(size=8)
        ))
        fig.add_hline(y=75, line_dash="dash", line_color="#888", annotation_text="Target")
        fig.update_layout(
            height=350,
            margin=dict(l=0, r=0, t=20, b=0),
            xaxis=dict(showgrid=False),
            yaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.1)', range=[0, 100]),
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)


def render_insights():
    """Render insights page."""
    st.markdown("**Key Insights**")

    insights = [
        {
            "title": "Sleep Quality Impact",
            "text": "Your recovery scores are 15% higher on days following 7+ hours of sleep. Consider maintaining a consistent sleep schedule.",
            "type": "info"
        },
        {
            "title": "Training Load",
            "text": "Your current training load is well-balanced. You've maintained consistent intensity without overtraining.",
            "type": "success"
        },
        {
            "title": "Rest Day Suggestion",
            "text": "Based on your recent activity, consider a light recovery day tomorrow to optimize adaptation.",
            "type": "warning"
        }
    ]

    for insight in insights:
        if insight["type"] == "success":
            st.success(f"**{insight['title']}**\n\n{insight['text']}")
        elif insight["type"] == "warning":
            st.warning(f"**{insight['title']}**\n\n{insight['text']}")
        else:
            st.info(f"**{insight['title']}**\n\n{insight['text']}")

    st.markdown("<br>", unsafe_allow_html=True)

    # Correlations
    st.markdown("**Metric Correlations**")

    correlation_data = {
        "Metric Pair": ["Sleep vs Recovery", "HRV vs Readiness", "Steps vs Calories"],
        "Correlation": [0.82, 0.75, 0.91],
        "Strength": ["Strong", "Moderate", "Very Strong"]
    }

    st.dataframe(
        pd.DataFrame(correlation_data),
        use_container_width=True,
        hide_index=True
    )


def render_nutrition():
    """Render nutrition tracking page."""
    if st.session_state.auth_token:
        data = get_live_data()
    else:
        data = get_demo_data()

    summary = data.get("nutrition_summary") or {}
    goal = data.get("nutrition_goal") or {}
    profile = data.get("physical_profile") or {}
    entries = data.get("food_entries") or []

    # Check if profile is complete
    if not profile.get("profile_complete", False) and st.session_state.auth_token:
        st.warning("Complete your physical profile to get personalized nutrition targets.")

        with st.expander("Set Up Physical Profile", expanded=True):
            col1, col2 = st.columns(2)
            with col1:
                age = st.number_input("Age", min_value=13, max_value=120, value=30)
                height = st.number_input("Height (cm)", min_value=100.0, max_value=250.0, value=170.0)
            with col2:
                gender = st.selectbox("Gender", ["male", "female", "other"])
                activity = st.selectbox(
                    "Activity Level",
                    ["sedentary", "light", "moderate", "active", "very_active"],
                    format_func=lambda x: x.replace("_", " ").title()
                )

            if st.button("Save Profile", type="primary"):
                result = api_request("/nutrition/physical-profile", "PUT", {
                    "age": age,
                    "height_cm": height,
                    "gender": gender,
                    "activity_level": activity
                })
                if result and result.get("success"):
                    st.success("Profile saved!")
                    st.rerun()
                else:
                    st.error(result.get("error", "Failed to save profile"))

        return

    # Calorie progress section
    total_cals = summary.get("total_calories", 0)
    target_cals = summary.get("calorie_target", 2000)
    remaining = summary.get("calories_remaining", target_cals - total_cals)
    cal_pct = min(100, (total_cals / target_cals * 100)) if target_cals > 0 else 0

    # Main metrics row
    cols = st.columns(4)
    with cols[0]:
        st.metric(
            label="Calories",
            value=f"{total_cals:.0f}",
            delta=f"{remaining:.0f} remaining"
        )
    with cols[1]:
        st.metric(
            label="Protein",
            value=f"{summary.get('total_protein_g', 0):.0f}g",
            delta=f"Target: {summary.get('protein_target_g', 0):.0f}g"
        )
    with cols[2]:
        st.metric(
            label="Carbs",
            value=f"{summary.get('total_carbs_g', 0):.0f}g",
            delta=f"Target: {summary.get('carbs_target_g', 0):.0f}g"
        )
    with cols[3]:
        st.metric(
            label="Fat",
            value=f"{summary.get('total_fat_g', 0):.0f}g",
            delta=f"Target: {summary.get('fat_target_g', 0):.0f}g"
        )

    st.markdown("<br>", unsafe_allow_html=True)

    # Charts row
    col1, col2 = st.columns(2)

    with col1:
        st.markdown("**Calorie Progress**")
        fig = go.Figure(go.Indicator(
            mode="gauge+number+delta",
            value=total_cals,
            delta={'reference': target_cals, 'relative': False, 'position': "bottom"},
            title={'text': "Calories Today"},
            gauge={
                'axis': {'range': [0, target_cals * 1.2]},
                'bar': {'color': "#22c55e" if cal_pct < 100 else "#f59e0b"},
                'steps': [
                    {'range': [0, target_cals * 0.8], 'color': "rgba(34, 197, 94, 0.1)"},
                    {'range': [target_cals * 0.8, target_cals], 'color': "rgba(34, 197, 94, 0.2)"},
                    {'range': [target_cals, target_cals * 1.2], 'color': "rgba(245, 158, 11, 0.2)"}
                ],
                'threshold': {
                    'line': {'color': "#888", 'width': 2},
                    'thickness': 0.75,
                    'value': target_cals
                }
            }
        ))
        fig.update_layout(
            height=250,
            margin=dict(l=20, r=20, t=40, b=20),
            paper_bgcolor='rgba(0,0,0,0)'
        )
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.markdown("**Macro Distribution**")
        protein = summary.get("total_protein_g", 0)
        carbs = summary.get("total_carbs_g", 0)
        fat = summary.get("total_fat_g", 0)

        if protein + carbs + fat > 0:
            fig = go.Figure(data=[go.Pie(
                labels=['Protein', 'Carbs', 'Fat'],
                values=[protein * 4, carbs * 4, fat * 9],  # Convert to calories
                hole=0.5,
                marker_colors=['#22c55e', '#3b82f6', '#f59e0b']
            )])
            fig.update_layout(
                height=250,
                margin=dict(l=20, r=20, t=20, b=20),
                paper_bgcolor='rgba(0,0,0,0)',
                showlegend=True,
                legend=dict(orientation="h", yanchor="bottom", y=-0.1, xanchor="center", x=0.5)
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("Log food to see macro distribution")

    st.markdown("<br>", unsafe_allow_html=True)

    # Macro progress bars
    st.markdown("**Macro Progress**")
    macro_cols = st.columns(3)

    with macro_cols[0]:
        protein_pct = summary.get("protein_progress_pct", 0)
        st.progress(min(100, protein_pct) / 100, text=f"Protein: {protein_pct:.0f}%")

    with macro_cols[1]:
        carbs_pct = summary.get("carbs_progress_pct", 0)
        st.progress(min(100, carbs_pct) / 100, text=f"Carbs: {carbs_pct:.0f}%")

    with macro_cols[2]:
        fat_pct = summary.get("fat_progress_pct", 0)
        st.progress(min(100, fat_pct) / 100, text=f"Fat: {fat_pct:.0f}%")

    st.markdown("<br>", unsafe_allow_html=True)

    # Two columns: Food log form and Today's entries
    col1, col2 = st.columns(2)

    with col1:
        st.markdown("**Log Food**")

        with st.form("food_log_form"):
            food_name = st.text_input("Food Name", placeholder="e.g., Grilled Chicken")
            meal_type = st.selectbox("Meal", ["breakfast", "lunch", "dinner", "snack"],
                                     format_func=lambda x: x.title())

            macro_cols = st.columns(4)
            with macro_cols[0]:
                calories = st.number_input("Calories", min_value=0, max_value=5000, value=0)
            with macro_cols[1]:
                protein_g = st.number_input("Protein (g)", min_value=0.0, max_value=500.0, value=0.0)
            with macro_cols[2]:
                carbs_g = st.number_input("Carbs (g)", min_value=0.0, max_value=500.0, value=0.0)
            with macro_cols[3]:
                fat_g = st.number_input("Fat (g)", min_value=0.0, max_value=500.0, value=0.0)

            submitted = st.form_submit_button("Log Food", type="primary", use_container_width=True)

            if submitted and st.session_state.auth_token:
                if food_name and calories > 0:
                    result = api_request("/nutrition/food", "POST", {
                        "name": food_name,
                        "meal_type": meal_type,
                        "calories": calories,
                        "protein_g": protein_g,
                        "carbs_g": carbs_g,
                        "fat_g": fat_g,
                        "fiber_g": 0,
                        "serving_size": 1,
                        "serving_unit": "serving"
                    })
                    if result and result.get("success"):
                        st.success("Food logged!")
                        st.rerun()
                    else:
                        st.error(result.get("error", "Failed to log food"))
                else:
                    st.warning("Please enter food name and calories")
            elif submitted:
                st.info("Sign in to log food")

    with col2:
        st.markdown("**Today's Food**")

        if entries:
            for entry in entries:
                meal = entry.get("meal_type", "snack").title()
                name = entry.get("name", "Unknown")
                cals = entry.get("calories", 0)
                prot = entry.get("protein_g", 0)
                carb = entry.get("carbs_g", 0)
                fat_val = entry.get("fat_g", 0)

                st.markdown(f"""
                <div style="padding: 0.75rem; margin-bottom: 0.5rem; border: 1px solid rgba(128,128,128,0.15); border-radius: 8px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span style="font-weight: 500;">{name}</span>
                            <span style="color: #888; font-size: 0.8rem; margin-left: 0.5rem;">{meal}</span>
                        </div>
                        <span style="font-weight: 600;">{cals:.0f} cal</span>
                    </div>
                    <div style="color: #888; font-size: 0.75rem; margin-top: 0.25rem;">
                        P: {prot:.0f}g | C: {carb:.0f}g | F: {fat_val:.0f}g
                    </div>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.info("No food logged today")

    # Goal settings section
    st.markdown("<br>", unsafe_allow_html=True)
    with st.expander("Nutrition Goal Settings"):
        goal_type = goal.get("goal_type", "general_health")
        goal_display = {
            "lose_weight": "Lose Weight",
            "build_muscle": "Build Muscle",
            "maintain": "Maintain Weight",
            "general_health": "General Health"
        }

        st.markdown(f"**Current Goal:** {goal_display.get(goal_type, goal_type)}")

        if goal.get("bmr"):
            cols = st.columns(3)
            with cols[0]:
                st.metric("BMR", f"{goal.get('bmr', 0):.0f} cal")
            with cols[1]:
                st.metric("TDEE", f"{goal.get('tdee', 0):.0f} cal")
            with cols[2]:
                st.metric("Target", f"{goal.get('calorie_target', 0):.0f} cal")

        if st.session_state.auth_token:
            new_goal = st.selectbox(
                "Change Goal",
                ["lose_weight", "build_muscle", "maintain", "general_health"],
                format_func=lambda x: goal_display.get(x, x),
                index=list(goal_display.keys()).index(goal_type) if goal_type in goal_display else 3
            )

            if st.button("Update Goal"):
                result = api_request("/nutrition/goals", "POST", {
                    "goal_type": new_goal,
                    "adjust_for_activity": True
                })
                if result and result.get("success"):
                    st.success("Goal updated!")
                    st.rerun()
                else:
                    st.error(result.get("error", "Failed to update goal"))


def render_settings():
    """Render settings page."""
    st.markdown("**Profile**")

    col1, col2 = st.columns(2)

    with col1:
        st.text_input("Email", value="demo@healthpulse.app", disabled=True)
        st.selectbox("Units", ["Metric (kg, km)", "Imperial (lbs, mi)"])

    with col2:
        st.number_input("Daily Step Goal", value=10000, step=500)
        st.number_input("Sleep Goal (hours)", value=8.0, step=0.5)

    st.markdown("<br>", unsafe_allow_html=True)
    st.markdown("**Data Sources**")

    sources = {
        "Source": ["Apple Health", "Fitbit", "Garmin", "Manual Entry"],
        "Status": ["Connected", "Not Connected", "Not Connected", "Active"]
    }

    st.dataframe(
        pd.DataFrame(sources),
        use_container_width=True,
        hide_index=True
    )

    st.markdown("<br>", unsafe_allow_html=True)

    if st.button("Sign Out", type="secondary"):
        st.session_state.auth_token = None
        st.session_state.user_email = None
        st.rerun()


def main():
    """Main app entry point."""
    init_session_state()

    # Show auth screen if not logged in
    if not st.session_state.auth_token:
        render_auth()
        return

    render_header()

    # Navigation tabs
    tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
        "Dashboard",
        "Nutrition",
        "Workouts",
        "Metrics",
        "Insights",
        "Settings"
    ])

    with tab1:
        render_dashboard()

    with tab2:
        render_nutrition()

    with tab3:
        render_workouts()

    with tab4:
        render_metrics()

    with tab5:
        render_insights()

    with tab6:
        render_settings()


if __name__ == "__main__":
    main()
