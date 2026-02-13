-- ============================================================================
-- Migration: Phase 9A — User Weekly Meal Plans
-- ============================================================================

-- ============================================================================
-- 1. TABLES
-- ============================================================================

CREATE TABLE public.user_weekly_meal_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    week_start_date DATE NOT NULL,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, week_start_date)
);

CREATE TABLE public.user_weekly_plan_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    plan_id UUID NOT NULL REFERENCES public.user_weekly_meal_plans(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id),
    servings DECIMAL NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. INDEXES
-- ============================================================================

CREATE INDEX idx_user_weekly_meal_plans_user_id
    ON public.user_weekly_meal_plans(user_id);

CREATE INDEX idx_user_weekly_meal_plans_user_week
    ON public.user_weekly_meal_plans(user_id, week_start_date);

CREATE INDEX idx_user_weekly_plan_items_plan_id
    ON public.user_weekly_plan_items(plan_id);

CREATE INDEX idx_user_weekly_plan_items_recipe_id
    ON public.user_weekly_plan_items(recipe_id);

-- ============================================================================
-- 3. ROW-LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.user_weekly_meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_weekly_plan_items ENABLE ROW LEVEL SECURITY;

-- Users can manage their own weekly plans
CREATE POLICY "users_manage_own_weekly_plans"
    ON public.user_weekly_meal_plans
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can manage items in their own weekly plans
CREATE POLICY "users_manage_own_weekly_plan_items"
    ON public.user_weekly_plan_items
    FOR ALL
    USING (
        plan_id IN (
            SELECT id FROM public.user_weekly_meal_plans
            WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        plan_id IN (
            SELECT id FROM public.user_weekly_meal_plans
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- 4. UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_weekly_meal_plans_updated_at
    BEFORE UPDATE ON public.user_weekly_meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
