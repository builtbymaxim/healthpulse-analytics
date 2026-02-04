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
    -- Physical profile for BMR/TDEE calculations
    age INTEGER CHECK (age >= 13 AND age <= 120),
    height_cm DECIMAL CHECK (height_cm >= 100 AND height_cm <= 250),
    gender TEXT,  -- 'male', 'female', 'other'
    activity_level TEXT DEFAULT 'moderate',  -- 'sedentary', 'light', 'moderate', 'active', 'very_active'
    fitness_goal TEXT,  -- 'lose_weight', 'build_muscle', 'maintain', 'general_health'
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
    -- Training plan fields (unified with workout_sessions)
    plan_id UUID REFERENCES public.user_training_plans(id) ON DELETE SET NULL,
    planned_workout_name TEXT,
    overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migration: Add plan columns to existing workouts table
-- ALTER TABLE public.workouts ADD COLUMN plan_id UUID REFERENCES public.user_training_plans(id) ON DELETE SET NULL;
-- ALTER TABLE public.workouts ADD COLUMN planned_workout_name TEXT;
-- ALTER TABLE public.workouts ADD COLUMN overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5);

-- Migration: Migrate workout_sessions data to workouts table
-- INSERT INTO public.workouts (user_id, workout_type, start_time, duration_minutes, intensity, notes, exercises, plan_id, planned_workout_name, overall_rating)
-- SELECT user_id, 'weight_training'::workout_type, started_at, COALESCE(duration_minutes, 60), 'moderate'::intensity_level, notes, exercises, plan_id, planned_workout_name, overall_rating
-- FROM public.workout_sessions;

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

-- ============================================
-- NUTRITION TRACKING (Calorie & Macro)
-- ============================================

-- Gender enum for BMR calculation
CREATE TYPE gender AS ENUM ('male', 'female', 'other');

-- Activity level for TDEE calculation
CREATE TYPE activity_level AS ENUM (
    'sedentary',     -- Little or no exercise (1.2)
    'light',         -- Exercise 1-3 days/week (1.375)
    'moderate',      -- Exercise 3-5 days/week (1.55)
    'active',        -- Exercise 6-7 days/week (1.725)
    'very_active'    -- Very intense daily exercise (1.9)
);

-- Nutrition goal types
CREATE TYPE nutrition_goal_type AS ENUM (
    'lose_weight',    -- TDEE - 500 cal deficit
    'build_muscle',   -- TDEE + 300 cal surplus
    'maintain',       -- TDEE maintenance
    'general_health'  -- Balanced nutrition
);

-- Meal type for food logging
CREATE TYPE meal_type AS ENUM (
    'breakfast', 'lunch', 'dinner', 'snack'
);

-- ============================================
-- NUTRITION GOALS TABLE
-- ============================================
CREATE TABLE public.nutrition_goals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    goal_type nutrition_goal_type NOT NULL DEFAULT 'general_health',

    -- Calculated targets (auto-updated when profile/goal changes)
    bmr DECIMAL,                      -- Basal Metabolic Rate
    tdee DECIMAL,                     -- Total Daily Energy Expenditure
    calorie_target DECIMAL,           -- Daily calorie goal
    protein_target_g DECIMAL,         -- Daily protein in grams
    carbs_target_g DECIMAL,           -- Daily carbs in grams
    fat_target_g DECIMAL,             -- Daily fat in grams

    -- Custom overrides (user can manually adjust)
    custom_calorie_target DECIMAL,
    custom_protein_target_g DECIMAL,
    custom_carbs_target_g DECIMAL,
    custom_fat_target_g DECIMAL,

    -- Settings
    adjust_for_activity BOOLEAN DEFAULT TRUE,  -- Adjust TDEE based on logged workouts

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id)  -- One active goal per user
);

CREATE INDEX idx_nutrition_goals_user
    ON public.nutrition_goals(user_id);

-- ============================================
-- FOOD ENTRIES TABLE
-- ============================================
CREATE TABLE public.food_entries (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,

    -- Food details
    name TEXT NOT NULL,
    meal_type meal_type,

    -- Nutrition values
    calories DECIMAL NOT NULL CHECK (calories >= 0),
    protein_g DECIMAL DEFAULT 0 CHECK (protein_g >= 0),
    carbs_g DECIMAL DEFAULT 0 CHECK (carbs_g >= 0),
    fat_g DECIMAL DEFAULT 0 CHECK (fat_g >= 0),
    fiber_g DECIMAL DEFAULT 0 CHECK (fiber_g >= 0),

    -- Serving info
    serving_size DECIMAL DEFAULT 1,
    serving_unit TEXT DEFAULT 'serving',

    -- Timing
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Source tracking
    source metric_source DEFAULT 'manual',
    notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_food_entries_user_date
    ON public.food_entries(user_id, logged_at DESC);

-- Extend daily_scores with nutrition data
-- Run as ALTER if table already exists:
-- ALTER TABLE public.daily_scores ADD COLUMN total_calories_in INTEGER;
-- ALTER TABLE public.daily_scores ADD COLUMN total_protein_g DECIMAL;
-- ALTER TABLE public.daily_scores ADD COLUMN total_carbs_g DECIMAL;
-- ALTER TABLE public.daily_scores ADD COLUMN total_fat_g DECIMAL;
-- ALTER TABLE public.daily_scores ADD COLUMN nutrition_score DECIMAL CHECK (nutrition_score >= 0 AND nutrition_score <= 100);

-- ============================================
-- NUTRITION RLS POLICIES
-- ============================================

ALTER TABLE public.nutrition_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_entries ENABLE ROW LEVEL SECURITY;

-- Nutrition Goals: Users can only manage their own goals
CREATE POLICY "Users can view own nutrition goals"
    ON public.nutrition_goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own nutrition goals"
    ON public.nutrition_goals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own nutrition goals"
    ON public.nutrition_goals FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own nutrition goals"
    ON public.nutrition_goals FOR DELETE
    USING (auth.uid() = user_id);

-- Food Entries: Users can only manage their own entries
CREATE POLICY "Users can view own food entries"
    ON public.food_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own food entries"
    ON public.food_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own food entries"
    ON public.food_entries FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own food entries"
    ON public.food_entries FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger for nutrition_goals updated_at
CREATE TRIGGER update_nutrition_goals_updated_at
    BEFORE UPDATE ON public.nutrition_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- EXERCISE LIBRARY & STRENGTH TRACKING
-- ============================================

-- Exercise categories
CREATE TYPE exercise_category AS ENUM (
    'chest', 'back', 'shoulders', 'arms', 'legs', 'core', 'cardio', 'other'
);

-- Equipment types
CREATE TYPE equipment_type AS ENUM (
    'barbell', 'dumbbell', 'cable', 'machine', 'bodyweight', 'kettlebell', 'bands', 'other'
);

-- Exercise input types (how sets are logged)
CREATE TYPE exercise_input_type AS ENUM (
    'weight_and_reps',  -- Standard: weight × reps (e.g., Bench Press: 80kg × 5)
    'reps_only',        -- Bodyweight: reps only (e.g., Push-up: 20 reps)
    'time_only',        -- Timed: duration in seconds (e.g., Plank: 60s)
    'distance_and_time' -- Cardio: distance and time (e.g., Run: 5km in 25min)
);

-- Global exercise library (shared across all users)
CREATE TABLE public.exercises (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category exercise_category NOT NULL,
    muscle_groups TEXT[] NOT NULL,
    equipment equipment_type,
    input_type exercise_input_type DEFAULT 'weight_and_reps',
    is_compound BOOLEAN DEFAULT FALSE,
    instructions TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migration: Add input_type column to existing exercises table
-- ALTER TABLE public.exercises ADD COLUMN input_type exercise_input_type DEFAULT 'weight_and_reps';

-- Migration: Update common bodyweight exercises
-- UPDATE public.exercises SET input_type = 'reps_only' WHERE name IN ('Push-up', 'Pull-up', 'Chin-up', 'Dip', 'Burpee', 'Sit-up', 'Crunch');

-- Migration: Update timed exercises
-- UPDATE public.exercises SET input_type = 'time_only' WHERE name IN ('Plank', 'Wall Sit', 'Dead Hang', 'Hollow Hold', 'L-Sit');

CREATE INDEX idx_exercises_category ON public.exercises(category);
CREATE INDEX idx_exercises_name ON public.exercises(name);

-- Set-by-set workout logging
CREATE TABLE public.workout_sets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    workout_id UUID REFERENCES public.workouts(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES public.exercises(id) NOT NULL,
    set_number INTEGER NOT NULL CHECK (set_number > 0),
    weight_kg DECIMAL NOT NULL CHECK (weight_kg >= 0),
    reps INTEGER NOT NULL CHECK (reps > 0),
    rpe DECIMAL CHECK (rpe >= 1 AND rpe <= 10),  -- Rate of Perceived Exertion
    is_warmup BOOLEAN DEFAULT FALSE,
    is_pr BOOLEAN DEFAULT FALSE,  -- Personal Record flag
    notes TEXT,
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workout_sets_user ON public.workout_sets(user_id);
CREATE INDEX idx_workout_sets_exercise ON public.workout_sets(exercise_id);
CREATE INDEX idx_workout_sets_workout ON public.workout_sets(workout_id);
CREATE INDEX idx_workout_sets_performed ON public.workout_sets(user_id, performed_at DESC);

-- Personal records tracking
CREATE TYPE pr_type AS ENUM (
    '1rm',       -- One rep max
    '3rm',       -- Three rep max
    '5rm',       -- Five rep max
    '10rm',      -- Ten rep max
    'max_reps',  -- Max reps at bodyweight
    'max_volume' -- Max volume in single session
);

CREATE TABLE public.personal_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    exercise_id UUID REFERENCES public.exercises(id),  -- Optional, for library exercises
    exercise_name TEXT,  -- For training plan exercises (may not be in library)
    record_type pr_type NOT NULL,
    value DECIMAL NOT NULL,  -- Weight in kg for rm types, reps for max_reps, kg for max_volume
    achieved_at TIMESTAMPTZ NOT NULL,
    workout_set_id UUID REFERENCES public.workout_sets(id) ON DELETE SET NULL,
    workout_session_id UUID REFERENCES public.workout_sessions(id) ON DELETE SET NULL,
    previous_value DECIMAL,  -- Previous PR value for comparison
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT pr_has_exercise CHECK (exercise_id IS NOT NULL OR exercise_name IS NOT NULL),
    UNIQUE(user_id, COALESCE(exercise_id::TEXT, exercise_name), record_type)
);

CREATE INDEX idx_personal_records_user ON public.personal_records(user_id);
CREATE INDEX idx_personal_records_exercise ON public.personal_records(exercise_id);

-- ============================================
-- EXERCISE RLS POLICIES
-- ============================================

-- Exercises table is public read (global library)
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view exercises"
    ON public.exercises FOR SELECT
    TO authenticated
    USING (TRUE);

-- Workout sets: Users can only manage their own
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own workout sets"
    ON public.workout_sets FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workout sets"
    ON public.workout_sets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workout sets"
    ON public.workout_sets FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workout sets"
    ON public.workout_sets FOR DELETE
    USING (auth.uid() = user_id);

-- Personal records: Users can only manage their own
ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own personal records"
    ON public.personal_records FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own personal records"
    ON public.personal_records FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own personal records"
    ON public.personal_records FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own personal records"
    ON public.personal_records FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- SEED EXERCISE LIBRARY
-- ============================================

INSERT INTO public.exercises (name, category, muscle_groups, equipment, is_compound) VALUES
-- Chest
('Bench Press', 'chest', ARRAY['pectoralis_major', 'triceps', 'anterior_deltoid'], 'barbell', TRUE),
('Incline Bench Press', 'chest', ARRAY['upper_pectoralis', 'triceps', 'anterior_deltoid'], 'barbell', TRUE),
('Dumbbell Bench Press', 'chest', ARRAY['pectoralis_major', 'triceps', 'anterior_deltoid'], 'dumbbell', TRUE),
('Dumbbell Flyes', 'chest', ARRAY['pectoralis_major'], 'dumbbell', FALSE),
('Cable Crossover', 'chest', ARRAY['pectoralis_major'], 'cable', FALSE),
('Push-up', 'chest', ARRAY['pectoralis_major', 'triceps', 'anterior_deltoid'], 'bodyweight', TRUE),
('Dips', 'chest', ARRAY['pectoralis_major', 'triceps'], 'bodyweight', TRUE),

-- Back
('Deadlift', 'back', ARRAY['erector_spinae', 'glutes', 'hamstrings', 'trapezius', 'latissimus_dorsi'], 'barbell', TRUE),
('Barbell Row', 'back', ARRAY['latissimus_dorsi', 'rhomboids', 'biceps', 'rear_deltoid'], 'barbell', TRUE),
('Pull-up', 'back', ARRAY['latissimus_dorsi', 'biceps', 'rhomboids'], 'bodyweight', TRUE),
('Chin-up', 'back', ARRAY['latissimus_dorsi', 'biceps'], 'bodyweight', TRUE),
('Lat Pulldown', 'back', ARRAY['latissimus_dorsi', 'biceps'], 'cable', TRUE),
('Seated Cable Row', 'back', ARRAY['latissimus_dorsi', 'rhomboids', 'biceps'], 'cable', TRUE),
('Dumbbell Row', 'back', ARRAY['latissimus_dorsi', 'rhomboids', 'biceps'], 'dumbbell', TRUE),
('T-Bar Row', 'back', ARRAY['latissimus_dorsi', 'rhomboids', 'biceps'], 'barbell', TRUE),
('Face Pull', 'back', ARRAY['rear_deltoid', 'rhomboids', 'trapezius'], 'cable', FALSE),

-- Legs
('Squat', 'legs', ARRAY['quadriceps', 'glutes', 'hamstrings', 'erector_spinae'], 'barbell', TRUE),
('Front Squat', 'legs', ARRAY['quadriceps', 'glutes', 'core'], 'barbell', TRUE),
('Leg Press', 'legs', ARRAY['quadriceps', 'glutes'], 'machine', TRUE),
('Romanian Deadlift', 'legs', ARRAY['hamstrings', 'glutes', 'erector_spinae'], 'barbell', TRUE),
('Leg Curl', 'legs', ARRAY['hamstrings'], 'machine', FALSE),
('Leg Extension', 'legs', ARRAY['quadriceps'], 'machine', FALSE),
('Lunges', 'legs', ARRAY['quadriceps', 'glutes', 'hamstrings'], 'dumbbell', TRUE),
('Bulgarian Split Squat', 'legs', ARRAY['quadriceps', 'glutes'], 'dumbbell', TRUE),
('Calf Raise', 'legs', ARRAY['gastrocnemius', 'soleus'], 'machine', FALSE),
('Hip Thrust', 'legs', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),

-- Shoulders
('Overhead Press', 'shoulders', ARRAY['anterior_deltoid', 'lateral_deltoid', 'triceps'], 'barbell', TRUE),
('Dumbbell Shoulder Press', 'shoulders', ARRAY['anterior_deltoid', 'lateral_deltoid', 'triceps'], 'dumbbell', TRUE),
('Lateral Raise', 'shoulders', ARRAY['lateral_deltoid'], 'dumbbell', FALSE),
('Front Raise', 'shoulders', ARRAY['anterior_deltoid'], 'dumbbell', FALSE),
('Rear Delt Fly', 'shoulders', ARRAY['rear_deltoid'], 'dumbbell', FALSE),
('Upright Row', 'shoulders', ARRAY['lateral_deltoid', 'trapezius'], 'barbell', TRUE),
('Arnold Press', 'shoulders', ARRAY['anterior_deltoid', 'lateral_deltoid', 'triceps'], 'dumbbell', TRUE),

-- Arms
('Barbell Curl', 'arms', ARRAY['biceps'], 'barbell', FALSE),
('Dumbbell Curl', 'arms', ARRAY['biceps'], 'dumbbell', FALSE),
('Hammer Curl', 'arms', ARRAY['biceps', 'brachialis'], 'dumbbell', FALSE),
('Preacher Curl', 'arms', ARRAY['biceps'], 'barbell', FALSE),
('Tricep Pushdown', 'arms', ARRAY['triceps'], 'cable', FALSE),
('Skull Crusher', 'arms', ARRAY['triceps'], 'barbell', FALSE),
('Close-Grip Bench Press', 'arms', ARRAY['triceps', 'pectoralis_major'], 'barbell', TRUE),
('Overhead Tricep Extension', 'arms', ARRAY['triceps'], 'dumbbell', FALSE),

-- Core
('Plank', 'core', ARRAY['rectus_abdominis', 'obliques', 'transverse_abdominis'], 'bodyweight', FALSE),
('Crunch', 'core', ARRAY['rectus_abdominis'], 'bodyweight', FALSE),
('Hanging Leg Raise', 'core', ARRAY['rectus_abdominis', 'hip_flexors'], 'bodyweight', FALSE),
('Cable Woodchop', 'core', ARRAY['obliques', 'rectus_abdominis'], 'cable', FALSE),
('Ab Wheel Rollout', 'core', ARRAY['rectus_abdominis', 'obliques'], 'other', FALSE),
('Russian Twist', 'core', ARRAY['obliques', 'rectus_abdominis'], 'bodyweight', FALSE);

-- ============================================
-- TRAINING PLANS
-- ============================================

-- Training plan templates (pre-built programs)
CREATE TABLE public.plan_templates (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    days_per_week INT NOT NULL,
    goal_type TEXT NOT NULL,
    sub_goals TEXT[],
    modality TEXT NOT NULL,
    equipment_required TEXT[],
    difficulty TEXT DEFAULT 'beginner',
    workouts JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User's active training plan
CREATE TABLE public.user_training_plans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    template_id UUID REFERENCES plan_templates(id),
    name TEXT NOT NULL,
    description TEXT,
    goal_type TEXT,
    sub_goal TEXT,
    schedule JSONB NOT NULL,
    customizations JSONB,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_training_plans_user ON user_training_plans(user_id);
CREATE INDEX idx_user_training_plans_active ON user_training_plans(user_id, is_active) WHERE is_active = true;

-- Workout sessions (full logging)
CREATE TABLE public.workout_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    plan_id UUID REFERENCES user_training_plans(id) ON DELETE SET NULL,
    planned_workout_name TEXT,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_minutes INT,
    exercises JSONB NOT NULL,
    overall_rating INT CHECK (overall_rating >= 1 AND overall_rating <= 5),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workout_sessions_user ON workout_sessions(user_id);
CREATE INDEX idx_workout_sessions_date ON workout_sessions(user_id, started_at DESC);

-- Exercise progress (aggregated for charts)
CREATE TABLE public.exercise_progress (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    exercise_id UUID REFERENCES exercises(id) NOT NULL,
    date DATE NOT NULL,
    best_weight DECIMAL,
    best_reps INT,
    total_volume DECIMAL,
    estimated_1rm DECIMAL,
    sets_completed INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, exercise_id, date)
);

CREATE INDEX idx_exercise_progress_user ON exercise_progress(user_id, exercise_id);

-- ============================================
-- TRAINING PLANS RLS POLICIES
-- ============================================

ALTER TABLE plan_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_progress ENABLE ROW LEVEL SECURITY;

-- Templates are public read
CREATE POLICY "Anyone can view templates" ON plan_templates FOR SELECT TO authenticated USING (true);

-- User data is private
CREATE POLICY "Users can view own plans" ON user_training_plans FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own plans" ON user_training_plans FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own plans" ON user_training_plans FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own plans" ON user_training_plans FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own sessions" ON workout_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sessions" ON workout_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sessions" ON workout_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own sessions" ON workout_sessions FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own progress" ON exercise_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own progress" ON exercise_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own progress" ON exercise_progress FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own progress" ON exercise_progress FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- SEED PLAN TEMPLATES
-- ============================================

INSERT INTO public.plan_templates (name, description, days_per_week, goal_type, sub_goals, modality, equipment_required, difficulty, workouts) VALUES
-- Full Body Strength (3 days)
(
    'Full Body Strength',
    'Hit every muscle group each session with compound movements. Great for beginners or those with limited time.',
    3,
    'build_strength',
    ARRAY['strength', 'muscle'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine'],
    'beginner',
    '[
        {"day": 1, "name": "Full Body A", "focus": "Squat Focus", "estimatedMinutes": 60, "exercises": [
            {"name": "Squat", "sets": 5, "reps": "5", "notes": "Key lift"},
            {"name": "Bench Press", "sets": 3, "reps": "8", "notes": null},
            {"name": "Barbell Row", "sets": 3, "reps": "8", "notes": null},
            {"name": "Dumbbell Shoulder Press", "sets": 3, "reps": "10", "notes": null},
            {"name": "Dumbbell Curl", "sets": 2, "reps": "12", "notes": null}
        ]},
        {"day": 3, "name": "Full Body B", "focus": "Deadlift Focus", "estimatedMinutes": 60, "exercises": [
            {"name": "Deadlift", "sets": 5, "reps": "5", "notes": "Key lift"},
            {"name": "Overhead Press", "sets": 3, "reps": "8", "notes": null},
            {"name": "Lat Pulldown", "sets": 3, "reps": "10", "notes": null},
            {"name": "Leg Press", "sets": 3, "reps": "12", "notes": null},
            {"name": "Tricep Pushdown", "sets": 2, "reps": "12", "notes": null}
        ]},
        {"day": 5, "name": "Full Body C", "focus": "Bench Focus", "estimatedMinutes": 60, "exercises": [
            {"name": "Bench Press", "sets": 5, "reps": "5", "notes": "Key lift"},
            {"name": "Front Squat", "sets": 3, "reps": "8", "notes": null},
            {"name": "Seated Cable Row", "sets": 3, "reps": "10", "notes": null},
            {"name": "Romanian Deadlift", "sets": 3, "reps": "10", "notes": null},
            {"name": "Face Pull", "sets": 2, "reps": "15", "notes": null}
        ]}
    ]'::jsonb
),
-- Upper/Lower Split (4 days)
(
    'Upper/Lower Split',
    'Balanced 4-day split alternating between upper and lower body. Ideal for intermediate lifters.',
    4,
    'build_muscle',
    ARRAY['muscle', 'strength'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine', 'bench'],
    'intermediate',
    '[
        {"day": 1, "name": "Upper Body A", "focus": "Push Focus", "estimatedMinutes": 60, "exercises": [
            {"name": "Bench Press", "sets": 4, "reps": "6", "notes": "Key lift"},
            {"name": "Overhead Press", "sets": 3, "reps": "8", "notes": null},
            {"name": "Barbell Row", "sets": 4, "reps": "8", "notes": null},
            {"name": "Lateral Raise", "sets": 3, "reps": "12", "notes": null},
            {"name": "Tricep Pushdown", "sets": 3, "reps": "12", "notes": null},
            {"name": "Dumbbell Curl", "sets": 3, "reps": "12", "notes": null}
        ]},
        {"day": 2, "name": "Lower Body A", "focus": "Quad Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Squat", "sets": 4, "reps": "6", "notes": "Key lift"},
            {"name": "Romanian Deadlift", "sets": 3, "reps": "10", "notes": null},
            {"name": "Leg Press", "sets": 3, "reps": "12", "notes": null},
            {"name": "Leg Curl", "sets": 3, "reps": "12", "notes": null},
            {"name": "Calf Raise", "sets": 4, "reps": "15", "notes": null}
        ]},
        {"day": 4, "name": "Upper Body B", "focus": "Pull Focus", "estimatedMinutes": 60, "exercises": [
            {"name": "Pull-up", "sets": 4, "reps": "8", "notes": "Key lift"},
            {"name": "Incline Bench Press", "sets": 3, "reps": "8", "notes": null},
            {"name": "Seated Cable Row", "sets": 4, "reps": "10", "notes": null},
            {"name": "Dumbbell Shoulder Press", "sets": 3, "reps": "10", "notes": null},
            {"name": "Face Pull", "sets": 3, "reps": "15", "notes": null},
            {"name": "Hammer Curl", "sets": 3, "reps": "12", "notes": null}
        ]},
        {"day": 5, "name": "Lower Body B", "focus": "Hip Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Deadlift", "sets": 4, "reps": "5", "notes": "Key lift"},
            {"name": "Bulgarian Split Squat", "sets": 3, "reps": "10", "notes": null},
            {"name": "Hip Thrust", "sets": 3, "reps": "12", "notes": null},
            {"name": "Leg Extension", "sets": 3, "reps": "15", "notes": null},
            {"name": "Calf Raise", "sets": 4, "reps": "12", "notes": null}
        ]}
    ]'::jsonb
),
-- Push Pull Legs (6 days)
(
    'Push Pull Legs',
    'High frequency split hitting each muscle twice per week. For those who can train 6 days.',
    6,
    'build_muscle',
    ARRAY['muscle', 'hypertrophy'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine', 'bench'],
    'intermediate',
    '[
        {"day": 1, "name": "Push A", "focus": "Chest Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Bench Press", "sets": 4, "reps": "6", "notes": "Key lift"},
            {"name": "Incline Dumbbell Press", "sets": 3, "reps": "10", "notes": null},
            {"name": "Overhead Press", "sets": 3, "reps": "8", "notes": null},
            {"name": "Lateral Raise", "sets": 3, "reps": "15", "notes": null},
            {"name": "Tricep Pushdown", "sets": 3, "reps": "12", "notes": null}
        ]},
        {"day": 2, "name": "Pull A", "focus": "Back Width", "estimatedMinutes": 55, "exercises": [
            {"name": "Pull-up", "sets": 4, "reps": "8", "notes": "Key lift"},
            {"name": "Barbell Row", "sets": 4, "reps": "8", "notes": null},
            {"name": "Face Pull", "sets": 3, "reps": "15", "notes": null},
            {"name": "Dumbbell Curl", "sets": 3, "reps": "12", "notes": null},
            {"name": "Hammer Curl", "sets": 2, "reps": "12", "notes": null}
        ]},
        {"day": 3, "name": "Legs A", "focus": "Quad Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Squat", "sets": 4, "reps": "6", "notes": "Key lift"},
            {"name": "Leg Press", "sets": 3, "reps": "12", "notes": null},
            {"name": "Romanian Deadlift", "sets": 3, "reps": "10", "notes": null},
            {"name": "Leg Curl", "sets": 3, "reps": "12", "notes": null},
            {"name": "Calf Raise", "sets": 4, "reps": "15", "notes": null}
        ]},
        {"day": 4, "name": "Push B", "focus": "Shoulder Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Overhead Press", "sets": 4, "reps": "6", "notes": "Key lift"},
            {"name": "Dumbbell Bench Press", "sets": 3, "reps": "10", "notes": null},
            {"name": "Cable Crossover", "sets": 3, "reps": "12", "notes": null},
            {"name": "Lateral Raise", "sets": 4, "reps": "12", "notes": null},
            {"name": "Skull Crusher", "sets": 3, "reps": "10", "notes": null}
        ]},
        {"day": 5, "name": "Pull B", "focus": "Back Thickness", "estimatedMinutes": 55, "exercises": [
            {"name": "Deadlift", "sets": 4, "reps": "5", "notes": "Key lift"},
            {"name": "Lat Pulldown", "sets": 4, "reps": "10", "notes": null},
            {"name": "Dumbbell Row", "sets": 3, "reps": "10", "notes": null},
            {"name": "Rear Delt Fly", "sets": 3, "reps": "15", "notes": null},
            {"name": "Barbell Curl", "sets": 3, "reps": "10", "notes": null}
        ]},
        {"day": 6, "name": "Legs B", "focus": "Hip Focus", "estimatedMinutes": 55, "exercises": [
            {"name": "Hip Thrust", "sets": 4, "reps": "10", "notes": "Key lift"},
            {"name": "Front Squat", "sets": 3, "reps": "8", "notes": null},
            {"name": "Leg Curl", "sets": 4, "reps": "12", "notes": null},
            {"name": "Bulgarian Split Squat", "sets": 3, "reps": "10", "notes": null},
            {"name": "Calf Raise", "sets": 4, "reps": "12", "notes": null}
        ]}
    ]'::jsonb
),
-- Home Bodyweight (3 days)
(
    'Home Bodyweight',
    'Build strength and muscle at home with no equipment needed. Perfect for beginners or traveling.',
    3,
    'general_health',
    ARRAY['strength', 'muscle', 'fitness'],
    'home',
    ARRAY[],
    'beginner',
    '[
        {"day": 1, "name": "Upper Body", "focus": "Push & Pull", "estimatedMinutes": 40, "exercises": [
            {"name": "Push-up", "sets": 4, "reps": "max", "notes": "Key lift"},
            {"name": "Dips", "sets": 3, "reps": "max", "notes": "Use chair or bench"},
            {"name": "Pull-up", "sets": 4, "reps": "max", "notes": "Key lift, or inverted rows"},
            {"name": "Plank", "sets": 3, "reps": "60s", "notes": null}
        ]},
        {"day": 3, "name": "Lower Body", "focus": "Legs", "estimatedMinutes": 35, "exercises": [
            {"name": "Bulgarian Split Squat", "sets": 4, "reps": "12", "notes": "Key lift, bodyweight"},
            {"name": "Lunges", "sets": 3, "reps": "12", "notes": "Each leg"},
            {"name": "Hip Thrust", "sets": 3, "reps": "15", "notes": "Single leg or elevated"},
            {"name": "Calf Raise", "sets": 4, "reps": "20", "notes": "Single leg on step"}
        ]},
        {"day": 5, "name": "Full Body", "focus": "Conditioning", "estimatedMinutes": 40, "exercises": [
            {"name": "Push-up", "sets": 3, "reps": "max", "notes": null},
            {"name": "Chin-up", "sets": 3, "reps": "max", "notes": "Or rows"},
            {"name": "Squat", "sets": 4, "reps": "20", "notes": "Bodyweight"},
            {"name": "Hanging Leg Raise", "sets": 3, "reps": "12", "notes": "Or lying"},
            {"name": "Russian Twist", "sets": 3, "reps": "20", "notes": null}
        ]}
    ]'::jsonb
);
