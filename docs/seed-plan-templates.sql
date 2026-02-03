-- ============================================
-- SEED PLAN TEMPLATES
-- Run this after creating the training plan tables
-- ============================================

-- 1. Full Body Strength (3 days/week)
INSERT INTO public.plan_templates (name, description, days_per_week, goal_type, sub_goals, modality, equipment_required, difficulty, workouts)
VALUES (
    'Full Body Strength',
    'Classic 3-day full body program. Perfect for beginners or busy schedules. Hit every muscle group each session with compound movements.',
    3,
    'build_strength',
    ARRAY['pure_strength', 'powerbuilding', 'general_fitness'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine'],
    'beginner',
    '[
        {
            "day": 1,
            "name": "Full Body A",
            "focus": "Squat Focus",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Barbell Squat", "sets": 3, "reps": "5", "restSeconds": 180, "isKeyLift": true, "notes": "Focus on depth and bracing"},
                {"name": "Bench Press", "sets": 3, "reps": "5", "restSeconds": 180, "isKeyLift": true},
                {"name": "Barbell Row", "sets": 3, "reps": "8", "restSeconds": 120, "isKeyLift": false},
                {"name": "Overhead Press", "sets": 3, "reps": "8", "restSeconds": 120, "isKeyLift": false},
                {"name": "Plank", "sets": 3, "reps": "30-60s", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 3,
            "name": "Full Body B",
            "focus": "Deadlift Focus",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Deadlift", "sets": 3, "reps": "5", "restSeconds": 180, "isKeyLift": true, "notes": "Reset each rep, maintain neutral spine"},
                {"name": "Incline Dumbbell Press", "sets": 3, "reps": "10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Lat Pulldown", "sets": 3, "reps": "10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Leg Press", "sets": 3, "reps": "12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Face Pulls", "sets": 3, "reps": "15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 5,
            "name": "Full Body C",
            "focus": "Bench Focus",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Bench Press", "sets": 3, "reps": "5", "restSeconds": 180, "isKeyLift": true},
                {"name": "Front Squat", "sets": 3, "reps": "8", "restSeconds": 120, "isKeyLift": false},
                {"name": "Dumbbell Row", "sets": 3, "reps": "10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Romanian Deadlift", "sets": 3, "reps": "10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Dumbbell Lateral Raise", "sets": 3, "reps": "12", "restSeconds": 60, "isKeyLift": false}
            ]
        }
    ]'::jsonb
);

-- 2. Upper/Lower Split (4 days/week)
INSERT INTO public.plan_templates (name, description, days_per_week, goal_type, sub_goals, modality, equipment_required, difficulty, workouts)
VALUES (
    'Upper/Lower Split',
    'Balanced 4-day split alternating between upper and lower body. Great for intermediates wanting more volume than full body.',
    4,
    'build_muscle',
    ARRAY['hypertrophy', 'lean_muscle', 'powerbuilding'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine', 'pullup_bar'],
    'intermediate',
    '[
        {
            "day": 1,
            "name": "Upper Body A",
            "focus": "Horizontal Push/Pull",
            "estimatedMinutes": 65,
            "exercises": [
                {"name": "Bench Press", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Barbell Row", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Overhead Press", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Lat Pulldown", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Dumbbell Curl", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 2,
            "name": "Lower Body A",
            "focus": "Quad Dominant",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "6-8", "restSeconds": 180, "isKeyLift": true},
                {"name": "Romanian Deadlift", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Leg Press", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Leg Curl", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Calf Raise", "sets": 4, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 4,
            "name": "Upper Body B",
            "focus": "Vertical Push/Pull",
            "estimatedMinutes": 65,
            "exercises": [
                {"name": "Overhead Press", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Pull-ups", "sets": 4, "reps": "6-10", "restSeconds": 150, "isKeyLift": true, "notes": "Add weight if needed"},
                {"name": "Incline Dumbbell Press", "sets": 3, "reps": "8-10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Cable Row", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Face Pulls", "sets": 3, "reps": "15-20", "restSeconds": 60, "isKeyLift": false},
                {"name": "Lateral Raise", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 5,
            "name": "Lower Body B",
            "focus": "Hip Dominant",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Deadlift", "sets": 4, "reps": "5", "restSeconds": 180, "isKeyLift": true},
                {"name": "Front Squat", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Bulgarian Split Squat", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Leg Extension", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Hanging Leg Raise", "sets": 3, "reps": "10-15", "restSeconds": 60, "isKeyLift": false}
            ]
        }
    ]'::jsonb
);

-- 3. Push/Pull/Legs (6 days/week)
INSERT INTO public.plan_templates (name, description, days_per_week, goal_type, sub_goals, modality, equipment_required, difficulty, workouts)
VALUES (
    'Push Pull Legs',
    'High frequency 6-day split. Each muscle hit twice per week. Best for those focused on muscle growth with time to train.',
    6,
    'build_muscle',
    ARRAY['hypertrophy', 'bodybuilding', 'lean_muscle'],
    'gym',
    ARRAY['barbell', 'dumbbells', 'cable_machine', 'pullup_bar'],
    'intermediate',
    '[
        {
            "day": 1,
            "name": "Push A",
            "focus": "Chest Emphasis",
            "estimatedMinutes": 55,
            "exercises": [
                {"name": "Bench Press", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Overhead Press", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Incline Dumbbell Press", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Cable Fly", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Lateral Raise", "sets": 3, "reps": "15-20", "restSeconds": 60, "isKeyLift": false},
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 2,
            "name": "Pull A",
            "focus": "Back Width",
            "estimatedMinutes": 55,
            "exercises": [
                {"name": "Barbell Row", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Pull-ups", "sets": 3, "reps": "8-12", "restSeconds": 120, "isKeyLift": false},
                {"name": "Lat Pulldown", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Face Pulls", "sets": 3, "reps": "15-20", "restSeconds": 60, "isKeyLift": false},
                {"name": "Barbell Curl", "sets": 3, "reps": "10-12", "restSeconds": 60, "isKeyLift": false},
                {"name": "Hammer Curl", "sets": 2, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 3,
            "name": "Legs A",
            "focus": "Quad Emphasis",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "6-8", "restSeconds": 180, "isKeyLift": true},
                {"name": "Leg Press", "sets": 3, "reps": "10-12", "restSeconds": 120, "isKeyLift": false},
                {"name": "Romanian Deadlift", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Leg Extension", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Leg Curl", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Calf Raise", "sets": 4, "reps": "15-20", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 4,
            "name": "Push B",
            "focus": "Shoulder Emphasis",
            "estimatedMinutes": 55,
            "exercises": [
                {"name": "Overhead Press", "sets": 4, "reps": "6-8", "restSeconds": 150, "isKeyLift": true},
                {"name": "Incline Bench Press", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Dumbbell Bench Press", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Lateral Raise", "sets": 4, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Overhead Tricep Extension", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 5,
            "name": "Pull B",
            "focus": "Back Thickness",
            "estimatedMinutes": 55,
            "exercises": [
                {"name": "Deadlift", "sets": 3, "reps": "5", "restSeconds": 180, "isKeyLift": true},
                {"name": "Cable Row", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Dumbbell Row", "sets": 3, "reps": "10-12", "restSeconds": 90, "isKeyLift": false},
                {"name": "Rear Delt Fly", "sets": 3, "reps": "15-20", "restSeconds": 60, "isKeyLift": false},
                {"name": "Preacher Curl", "sets": 3, "reps": "10-12", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 6,
            "name": "Legs B",
            "focus": "Hamstring Emphasis",
            "estimatedMinutes": 60,
            "exercises": [
                {"name": "Deadlift", "sets": 4, "reps": "6-8", "restSeconds": 180, "isKeyLift": true},
                {"name": "Front Squat", "sets": 3, "reps": "8-10", "restSeconds": 120, "isKeyLift": false},
                {"name": "Walking Lunges", "sets": 3, "reps": "12 each", "restSeconds": 90, "isKeyLift": false},
                {"name": "Leg Curl", "sets": 4, "reps": "10-12", "restSeconds": 60, "isKeyLift": false},
                {"name": "Hip Thrust", "sets": 3, "reps": "12-15", "restSeconds": 90, "isKeyLift": false},
                {"name": "Calf Raise", "sets": 4, "reps": "12-15", "restSeconds": 60, "isKeyLift": false}
            ]
        }
    ]'::jsonb
);

-- 4. Home Bodyweight (3-4 days/week)
INSERT INTO public.plan_templates (name, description, days_per_week, goal_type, sub_goals, modality, equipment_required, difficulty, workouts)
VALUES (
    'Home Bodyweight',
    'No equipment needed. Build strength and muscle at home with progressive bodyweight exercises. Great for beginners or travel.',
    3,
    'general_fitness',
    ARRAY['balanced_health', 'active_lifestyle', 'lean_muscle'],
    'home',
    ARRAY['pullup_bar'],
    'beginner',
    '[
        {
            "day": 1,
            "name": "Upper Body",
            "focus": "Push & Pull",
            "estimatedMinutes": 40,
            "exercises": [
                {"name": "Push-ups", "sets": 4, "reps": "max", "restSeconds": 90, "isKeyLift": true, "notes": "Elevate hands if needed"},
                {"name": "Pike Push-ups", "sets": 3, "reps": "8-12", "restSeconds": 90, "isKeyLift": false, "notes": "For shoulders"},
                {"name": "Pull-ups", "sets": 4, "reps": "max", "restSeconds": 120, "isKeyLift": true, "notes": "Use bands if needed"},
                {"name": "Inverted Rows", "sets": 3, "reps": "10-15", "restSeconds": 90, "isKeyLift": false, "notes": "Use table or low bar"},
                {"name": "Diamond Push-ups", "sets": 3, "reps": "8-12", "restSeconds": 60, "isKeyLift": false},
                {"name": "Plank", "sets": 3, "reps": "45-60s", "restSeconds": 60, "isKeyLift": false}
            ]
        },
        {
            "day": 3,
            "name": "Lower Body",
            "focus": "Legs & Core",
            "estimatedMinutes": 40,
            "exercises": [
                {"name": "Bodyweight Squat", "sets": 4, "reps": "15-20", "restSeconds": 60, "isKeyLift": true},
                {"name": "Bulgarian Split Squat", "sets": 3, "reps": "10-12 each", "restSeconds": 90, "isKeyLift": true},
                {"name": "Romanian Single Leg Deadlift", "sets": 3, "reps": "10-12 each", "restSeconds": 60, "isKeyLift": false},
                {"name": "Glute Bridge", "sets": 3, "reps": "15-20", "restSeconds": 60, "isKeyLift": false},
                {"name": "Calf Raise", "sets": 4, "reps": "20-25", "restSeconds": 45, "isKeyLift": false},
                {"name": "Dead Bug", "sets": 3, "reps": "10 each", "restSeconds": 45, "isKeyLift": false}
            ]
        },
        {
            "day": 5,
            "name": "Full Body",
            "focus": "Conditioning",
            "estimatedMinutes": 45,
            "exercises": [
                {"name": "Burpees", "sets": 4, "reps": "10", "restSeconds": 90, "isKeyLift": false},
                {"name": "Chin-ups", "sets": 3, "reps": "max", "restSeconds": 120, "isKeyLift": true},
                {"name": "Archer Push-ups", "sets": 3, "reps": "6-8 each", "restSeconds": 90, "isKeyLift": false},
                {"name": "Jump Squat", "sets": 3, "reps": "12-15", "restSeconds": 60, "isKeyLift": false},
                {"name": "Mountain Climbers", "sets": 3, "reps": "30s", "restSeconds": 45, "isKeyLift": false},
                {"name": "Hollow Body Hold", "sets": 3, "reps": "30-45s", "restSeconds": 45, "isKeyLift": false}
            ]
        }
    ]'::jsonb
);

-- Verify inserts
SELECT name, days_per_week, goal_type, modality, difficulty FROM plan_templates ORDER BY days_per_week;
