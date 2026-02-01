-- HealthPulse Migration: Exercise & Strength Tracking
-- Run this in Supabase SQL Editor to add the new exercise tables

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

-- PR types
CREATE TYPE pr_type AS ENUM (
    '1rm',       -- One rep max
    '3rm',       -- Three rep max
    '5rm',       -- Five rep max
    '10rm',      -- Ten rep max
    'max_reps',  -- Max reps at bodyweight
    'max_volume' -- Max volume in single session
);

-- Global exercise library (shared across all users)
CREATE TABLE public.exercises (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category exercise_category NOT NULL,
    muscle_groups TEXT[] NOT NULL,
    equipment equipment_type,
    is_compound BOOLEAN DEFAULT FALSE,
    instructions TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

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
    rpe DECIMAL CHECK (rpe >= 1 AND rpe <= 10),
    is_warmup BOOLEAN DEFAULT FALSE,
    is_pr BOOLEAN DEFAULT FALSE,
    notes TEXT,
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_workout_sets_user ON public.workout_sets(user_id);
CREATE INDEX idx_workout_sets_exercise ON public.workout_sets(exercise_id);
CREATE INDEX idx_workout_sets_workout ON public.workout_sets(workout_id);
CREATE INDEX idx_workout_sets_performed ON public.workout_sets(user_id, performed_at DESC);

-- Personal records tracking
CREATE TABLE public.personal_records (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    exercise_id UUID REFERENCES public.exercises(id) NOT NULL,
    record_type pr_type NOT NULL,
    value DECIMAL NOT NULL,
    achieved_at TIMESTAMPTZ NOT NULL,
    workout_set_id UUID REFERENCES public.workout_sets(id) ON DELETE SET NULL,
    previous_value DECIMAL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, exercise_id, record_type)
);

CREATE INDEX idx_personal_records_user ON public.personal_records(user_id);
CREATE INDEX idx_personal_records_exercise ON public.personal_records(exercise_id);

-- ============================================
-- RLS POLICIES
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
