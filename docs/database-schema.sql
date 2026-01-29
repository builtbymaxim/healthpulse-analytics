-- HealthPulse Database Schema for Supabase
-- Run this in the Supabase SQL Editor to set up your database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- USERS TABLE (extends Supabase auth.users)
-- ============================================
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    settings JSONB DEFAULT '{
        "units": "metric",
        "timezone": "UTC",
        "notifications_enabled": true,
        "daily_goals": {
            "steps": 10000,
            "active_calories": 500,
            "sleep_hours": 8,
            "water_liters": 2.5
        }
    }'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- HEALTH METRICS TABLE
-- ============================================
CREATE TYPE metric_type AS ENUM (
    'steps', 'active_calories', 'distance',
    'weight', 'body_fat',
    'heart_rate', 'resting_hr', 'hrv',
    'sleep_duration', 'sleep_quality', 'deep_sleep', 'rem_sleep',
    'calories_in', 'protein', 'carbs', 'fat', 'water',
    'energy_level', 'mood', 'stress', 'soreness'
);

CREATE TYPE metric_source AS ENUM (
    'manual', 'apple_health', 'garmin', 'fitbit', 'whoop', 'oura'
);

CREATE TABLE public.health_metrics (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    metric_type metric_type NOT NULL,
    value DECIMAL NOT NULL,
    unit TEXT,
    timestamp TIMESTAMPTZ NOT NULL,
    source metric_source DEFAULT 'manual',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient querying
CREATE INDEX idx_metrics_user_type_time
    ON public.health_metrics(user_id, metric_type, timestamp DESC);
CREATE INDEX idx_metrics_user_timestamp
    ON public.health_metrics(user_id, timestamp DESC);

-- ============================================
-- WORKOUTS TABLE
-- ============================================
CREATE TYPE workout_type AS ENUM (
    'running', 'cycling', 'swimming', 'walking', 'hiking', 'rowing',
    'weight_training', 'bodyweight', 'crossfit',
    'yoga', 'pilates', 'stretching',
    'hiit', 'other'
);

CREATE TYPE intensity_level AS ENUM (
    'light', 'moderate', 'hard', 'very_hard'
);

CREATE TABLE public.workouts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    workout_type workout_type NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    intensity intensity_level DEFAULT 'moderate',
    calories_burned INTEGER,
    distance_km DECIMAL,
    avg_heart_rate INTEGER,
    max_heart_rate INTEGER,
    training_load DECIMAL, -- Calculated field
    notes TEXT,
    exercises JSONB, -- For strength workouts: [{name, sets, reps, weight}]
    source metric_source DEFAULT 'manual',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workouts_user_time
    ON public.workouts(user_id, start_time DESC);

-- ============================================
-- DAILY SCORES TABLE
-- ============================================
CREATE TABLE public.daily_scores (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,

    -- Aggregated metrics
    total_steps INTEGER,
    total_active_calories INTEGER,
    total_sleep_minutes INTEGER,
    avg_sleep_quality DECIMAL,
    avg_resting_hr INTEGER,
    avg_hrv DECIMAL,

    -- Calculated scores (0-100)
    wellness_score DECIMAL CHECK (wellness_score >= 0 AND wellness_score <= 100),
    recovery_score DECIMAL CHECK (recovery_score >= 0 AND recovery_score <= 100),
    readiness_score DECIMAL CHECK (readiness_score >= 0 AND readiness_score <= 100),
    activity_score DECIMAL CHECK (activity_score >= 0 AND activity_score <= 100),
    sleep_score DECIMAL CHECK (sleep_score >= 0 AND sleep_score <= 100),

    -- Subjective ratings (1-10)
    energy_level INTEGER CHECK (energy_level >= 1 AND energy_level <= 10),
    mood INTEGER CHECK (mood >= 1 AND mood <= 10),
    stress_level INTEGER CHECK (stress_level >= 1 AND stress_level <= 10),
    soreness_level INTEGER CHECK (soreness_level >= 1 AND soreness_level <= 10),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, date)
);

CREATE INDEX idx_daily_scores_user_date
    ON public.daily_scores(user_id, date DESC);

-- ============================================
-- PREDICTIONS TABLE
-- ============================================
CREATE TYPE prediction_type AS ENUM (
    'recovery', 'readiness', 'sleep_quality', 'wellness_trend'
);

CREATE TABLE public.predictions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    prediction_type prediction_type NOT NULL,
    predicted_value DECIMAL NOT NULL,
    confidence DECIMAL CHECK (confidence >= 0 AND confidence <= 1),
    input_features JSONB,
    contributing_factors JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_predictions_user_type
    ON public.predictions(user_id, prediction_type, created_at DESC);

-- ============================================
-- INSIGHTS TABLE
-- ============================================
CREATE TYPE insight_category AS ENUM (
    'correlation', 'anomaly', 'trend', 'recommendation', 'achievement'
);

CREATE TABLE public.insights (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    category insight_category NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    supporting_data JSONB,
    priority INTEGER DEFAULT 0,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

CREATE INDEX idx_insights_user_unread
    ON public.insights(user_id, is_read, created_at DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insights ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only access their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Health Metrics: Users can only access their own data
CREATE POLICY "Users can view own metrics"
    ON public.health_metrics FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own metrics"
    ON public.health_metrics FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own metrics"
    ON public.health_metrics FOR DELETE
    USING (auth.uid() = user_id);

-- Workouts: Users can only access their own workouts
CREATE POLICY "Users can view own workouts"
    ON public.workouts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workouts"
    ON public.workouts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workouts"
    ON public.workouts FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workouts"
    ON public.workouts FOR DELETE
    USING (auth.uid() = user_id);

-- Daily Scores: Users can only access their own scores
CREATE POLICY "Users can view own daily scores"
    ON public.daily_scores FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own daily scores"
    ON public.daily_scores FOR ALL
    USING (auth.uid() = user_id);

-- Predictions: Users can only view their own predictions
CREATE POLICY "Users can view own predictions"
    ON public.predictions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own predictions"
    ON public.predictions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Insights: Users can only access their own insights
CREATE POLICY "Users can view own insights"
    ON public.insights FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own insights"
    ON public.insights FOR UPDATE
    USING (auth.uid() = user_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_daily_scores_updated_at
    BEFORE UPDATE ON public.daily_scores
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
