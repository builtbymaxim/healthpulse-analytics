-- ============================================================================
-- Migration: Meal Plans (recipes, meal_plan_templates, meal_plan_items)
-- ============================================================================

-- ============================================================================
-- 1. TABLES
-- ============================================================================

CREATE TABLE public.recipes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    description TEXT,
    ingredients JSONB NOT NULL,
    instructions TEXT[],
    prep_time_min INTEGER,
    cook_time_min INTEGER,
    servings INTEGER NOT NULL DEFAULT 1,
    calories_per_serving DECIMAL NOT NULL,
    protein_g_per_serving DECIMAL NOT NULL DEFAULT 0,
    carbs_g_per_serving DECIMAL NOT NULL DEFAULT 0,
    fat_g_per_serving DECIMAL NOT NULL DEFAULT 0,
    fiber_g_per_serving DECIMAL NOT NULL DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    goal_types TEXT[] DEFAULT '{}',
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.meal_plan_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    goal_type TEXT NOT NULL,
    total_calories DECIMAL NOT NULL,
    total_protein_g DECIMAL NOT NULL DEFAULT 0,
    total_carbs_g DECIMAL NOT NULL DEFAULT 0,
    total_fat_g DECIMAL NOT NULL DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.meal_plan_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    template_id UUID REFERENCES public.meal_plan_templates(id) ON DELETE CASCADE NOT NULL,
    recipe_id UUID REFERENCES public.recipes(id) NOT NULL,
    meal_type TEXT NOT NULL,
    servings DECIMAL NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plan_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plan_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read recipes"
    ON public.recipes FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can read meal plan templates"
    ON public.meal_plan_templates FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can read meal plan items"
    ON public.meal_plan_items FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================================
-- 3. INDEXES
-- ============================================================================

CREATE INDEX idx_recipes_category ON public.recipes(category);
CREATE INDEX idx_recipes_goal_types ON public.recipes USING GIN(goal_types);
CREATE INDEX idx_recipes_tags ON public.recipes USING GIN(tags);
CREATE INDEX idx_recipes_calories ON public.recipes(calories_per_serving);

CREATE INDEX idx_meal_plan_templates_goal_type ON public.meal_plan_templates(goal_type);
CREATE INDEX idx_meal_plan_templates_tags ON public.meal_plan_templates USING GIN(tags);

CREATE INDEX idx_meal_plan_items_template_id ON public.meal_plan_items(template_id);
CREATE INDEX idx_meal_plan_items_recipe_id ON public.meal_plan_items(recipe_id);
CREATE INDEX idx_meal_plan_items_sort_order ON public.meal_plan_items(template_id, sort_order);

-- ============================================================================
-- 4. SEED DATA: RECIPES (35 total)
-- ============================================================================

-- We use fixed UUIDs so meal_plan_items can reference them.

-- ---- BREAKFAST (7) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'a0000000-0000-0000-0000-000000000001',
    'Greek Yogurt Parfait',
    'breakfast',
    'Layered Greek yogurt with granola, mixed berries, and a drizzle of honey for a protein-rich start.',
    '[{"name": "Greek yogurt (0% fat)", "amount": 200, "unit": "g"}, {"name": "granola", "amount": 40, "unit": "g"}, {"name": "mixed berries", "amount": 80, "unit": "g"}, {"name": "honey", "amount": 10, "unit": "g"}]'::jsonb,
    ARRAY['Spoon half the yogurt into a glass or bowl.', 'Add a layer of granola and half the berries.', 'Add remaining yogurt on top.', 'Finish with remaining berries and drizzle honey.'],
    5, 0, 1,
    310, 22, 42, 5, 3,
    ARRAY['high_protein', 'quick', 'gluten_free'],
    ARRAY['lose_weight', 'maintain', 'general_health']
),
(
    'a0000000-0000-0000-0000-000000000002',
    'Protein Oats',
    'breakfast',
    'Hearty rolled oats cooked with milk and topped with a scoop of whey protein and banana slices.',
    '[{"name": "rolled oats", "amount": 80, "unit": "g"}, {"name": "whole milk", "amount": 200, "unit": "ml"}, {"name": "whey protein powder", "amount": 30, "unit": "g"}, {"name": "banana", "amount": 1, "unit": "medium"}, {"name": "cinnamon", "amount": 1, "unit": "tsp"}]'::jsonb,
    ARRAY['Combine oats and milk in a saucepan over medium heat.', 'Cook for 4-5 minutes, stirring occasionally, until thickened.', 'Remove from heat and stir in protein powder until smooth.', 'Top with sliced banana and a pinch of cinnamon.'],
    3, 5, 1,
    480, 35, 62, 8, 6,
    ARRAY['high_protein', 'high_fiber'],
    ARRAY['build_muscle', 'maintain']
),
(
    'a0000000-0000-0000-0000-000000000003',
    'Egg White Omelette',
    'breakfast',
    'Fluffy egg white omelette loaded with spinach, mushrooms, and bell peppers for a low-calorie protein boost.',
    '[{"name": "egg whites", "amount": 200, "unit": "ml"}, {"name": "fresh spinach", "amount": 40, "unit": "g"}, {"name": "mushrooms", "amount": 50, "unit": "g"}, {"name": "red bell pepper", "amount": 50, "unit": "g"}, {"name": "olive oil spray", "amount": 1, "unit": "spray"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Dice mushrooms and bell pepper into small pieces.', 'Heat a non-stick pan over medium heat and spray with olive oil.', 'Saute mushrooms and peppers for 2 minutes until softened.', 'Pour in egg whites and tilt the pan to spread evenly.', 'Add spinach on one half when the bottom is set.', 'Fold the omelette and cook for another minute.', 'Season with salt and pepper and serve.'],
    5, 6, 1,
    180, 30, 6, 2, 2,
    ARRAY['high_protein', 'low_carb', 'low_fat', 'gluten_free', 'dairy_free', 'quick'],
    ARRAY['lose_weight', 'build_muscle']
),
(
    'a0000000-0000-0000-0000-000000000004',
    'Overnight Oats',
    'breakfast',
    'No-cook oats soaked overnight in almond milk with chia seeds and topped with fresh strawberries.',
    '[{"name": "rolled oats", "amount": 60, "unit": "g"}, {"name": "almond milk (unsweetened)", "amount": 180, "unit": "ml"}, {"name": "chia seeds", "amount": 15, "unit": "g"}, {"name": "strawberries", "amount": 80, "unit": "g"}, {"name": "maple syrup", "amount": 10, "unit": "ml"}]'::jsonb,
    ARRAY['Combine oats, almond milk, and chia seeds in a jar.', 'Stir well, cover, and refrigerate overnight (at least 6 hours).', 'In the morning, stir the mixture and add more milk if too thick.', 'Top with sliced strawberries and drizzle with maple syrup.'],
    5, 0, 1,
    340, 12, 52, 9, 8,
    ARRAY['high_fiber', 'vegetarian', 'dairy_free', 'quick'],
    ARRAY['general_health', 'maintain']
),
(
    'a0000000-0000-0000-0000-000000000005',
    'Avocado Toast',
    'breakfast',
    'Whole-grain toast topped with smashed avocado, cherry tomatoes, and a poached egg.',
    '[{"name": "whole-grain bread", "amount": 2, "unit": "slices"}, {"name": "avocado", "amount": 0.5, "unit": "whole"}, {"name": "cherry tomatoes", "amount": 60, "unit": "g"}, {"name": "egg", "amount": 1, "unit": "large"}, {"name": "lemon juice", "amount": 5, "unit": "ml"}, {"name": "red pepper flakes", "amount": 1, "unit": "pinch"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Toast the bread slices until golden.', 'Mash the avocado with lemon juice and salt in a bowl.', 'Poach the egg in simmering water with a splash of vinegar for 3 minutes.', 'Spread the avocado mash evenly on both slices of toast.', 'Halve the cherry tomatoes and arrange on top.', 'Place the poached egg on one slice and sprinkle red pepper flakes.'],
    5, 5, 1,
    380, 16, 34, 20, 8,
    ARRAY['high_fiber', 'vegetarian', 'quick'],
    ARRAY['general_health', 'maintain']
),
(
    'a0000000-0000-0000-0000-000000000006',
    'Protein Pancakes',
    'breakfast',
    'Fluffy pancakes made with oats and protein powder, served with fresh blueberries and a light drizzle of syrup.',
    '[{"name": "rolled oats", "amount": 50, "unit": "g"}, {"name": "whey protein powder", "amount": 30, "unit": "g"}, {"name": "egg", "amount": 1, "unit": "large"}, {"name": "banana", "amount": 0.5, "unit": "medium"}, {"name": "baking powder", "amount": 3, "unit": "g"}, {"name": "almond milk (unsweetened)", "amount": 60, "unit": "ml"}, {"name": "blueberries", "amount": 50, "unit": "g"}, {"name": "maple syrup", "amount": 10, "unit": "ml"}]'::jsonb,
    ARRAY['Blend oats into a flour using a blender.', 'Combine oat flour, protein powder, and baking powder in a bowl.', 'In a separate bowl, mash the banana and whisk with the egg and almond milk.', 'Mix wet and dry ingredients until just combined.', 'Heat a non-stick pan over medium heat and pour small rounds of batter.', 'Cook until bubbles form on the surface, then flip and cook another minute.', 'Serve topped with blueberries and a drizzle of maple syrup.'],
    10, 8, 1,
    420, 32, 50, 8, 5,
    ARRAY['high_protein', 'high_fiber'],
    ARRAY['build_muscle', 'maintain']
),
(
    'a0000000-0000-0000-0000-000000000007',
    'Scrambled Eggs & Toast',
    'breakfast',
    'Classic soft-scrambled eggs with buttered whole-wheat toast and a side of fresh tomato slices.',
    '[{"name": "eggs", "amount": 3, "unit": "large"}, {"name": "whole-wheat bread", "amount": 2, "unit": "slices"}, {"name": "butter", "amount": 10, "unit": "g"}, {"name": "whole milk", "amount": 20, "unit": "ml"}, {"name": "tomato", "amount": 1, "unit": "medium"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}, {"name": "chives", "amount": 5, "unit": "g"}]'::jsonb,
    ARRAY['Crack eggs into a bowl, add milk, salt, and pepper, and whisk well.', 'Melt butter in a non-stick pan over medium-low heat.', 'Pour in the egg mixture and stir gently with a spatula.', 'Continue stirring until eggs are softly set but still slightly creamy.', 'Toast the bread slices and slice the tomato.', 'Plate the scrambled eggs alongside the toast and tomato slices.', 'Garnish with chopped chives.'],
    5, 5, 1,
    430, 24, 32, 22, 4,
    ARRAY['quick', 'vegetarian'],
    ARRAY['build_muscle', 'maintain', 'general_health']
);

-- ---- LUNCH (8) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'b0000000-0000-0000-0000-000000000001',
    'Grilled Chicken Salad',
    'lunch',
    'Tender grilled chicken breast over a bed of mixed greens with cucumbers, tomatoes, and a light vinaigrette.',
    '[{"name": "chicken breast", "amount": 180, "unit": "g"}, {"name": "mixed salad greens", "amount": 100, "unit": "g"}, {"name": "cucumber", "amount": 80, "unit": "g"}, {"name": "cherry tomatoes", "amount": 80, "unit": "g"}, {"name": "red onion", "amount": 30, "unit": "g"}, {"name": "olive oil", "amount": 10, "unit": "ml"}, {"name": "balsamic vinegar", "amount": 15, "unit": "ml"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Season chicken breast with salt and pepper.', 'Grill chicken on medium-high heat for 6-7 minutes per side until cooked through.', 'Let chicken rest for 3 minutes, then slice.', 'Toss greens, cucumber, tomatoes, and red onion in a large bowl.', 'Whisk olive oil and balsamic vinegar together for the dressing.', 'Top the salad with sliced chicken and drizzle with dressing.'],
    10, 14, 1,
    380, 42, 12, 18, 3,
    ARRAY['high_protein', 'low_carb', 'gluten_free', 'dairy_free'],
    ARRAY['lose_weight', 'build_muscle']
),
(
    'b0000000-0000-0000-0000-000000000002',
    'Tuna Wrap',
    'lunch',
    'Canned tuna mixed with Greek yogurt and Dijon mustard, wrapped in a whole-wheat tortilla with lettuce and tomato.',
    '[{"name": "canned tuna (in water, drained)", "amount": 140, "unit": "g"}, {"name": "Greek yogurt (0% fat)", "amount": 30, "unit": "g"}, {"name": "Dijon mustard", "amount": 5, "unit": "g"}, {"name": "whole-wheat tortilla (10-inch)", "amount": 1, "unit": "piece"}, {"name": "romaine lettuce", "amount": 40, "unit": "g"}, {"name": "tomato", "amount": 50, "unit": "g"}, {"name": "red onion", "amount": 15, "unit": "g"}, {"name": "lemon juice", "amount": 5, "unit": "ml"}]'::jsonb,
    ARRAY['Drain the tuna and place in a mixing bowl.', 'Add Greek yogurt, Dijon mustard, and lemon juice, then mix well.', 'Warm the tortilla briefly in a dry pan.', 'Layer lettuce and tomato slices on the tortilla.', 'Spread the tuna mixture over the vegetables.', 'Add sliced red onion, roll tightly, and slice in half.'],
    10, 0, 1,
    350, 38, 30, 8, 4,
    ARRAY['high_protein', 'low_fat', 'quick'],
    ARRAY['lose_weight', 'maintain']
),
(
    'b0000000-0000-0000-0000-000000000003',
    'Turkey & Quinoa Bowl',
    'lunch',
    'Seasoned ground turkey served over fluffy quinoa with roasted sweet potatoes and steamed broccoli.',
    '[{"name": "ground turkey (93% lean)", "amount": 150, "unit": "g"}, {"name": "quinoa (dry)", "amount": 70, "unit": "g"}, {"name": "sweet potato", "amount": 120, "unit": "g"}, {"name": "broccoli florets", "amount": 100, "unit": "g"}, {"name": "olive oil", "amount": 10, "unit": "ml"}, {"name": "garlic powder", "amount": 2, "unit": "g"}, {"name": "smoked paprika", "amount": 2, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Preheat oven to 200C / 400F.', 'Dice sweet potato, toss with half the olive oil, and roast for 20 minutes.', 'Rinse quinoa and cook in 140ml water for 15 minutes until fluffy.', 'Steam broccoli for 4-5 minutes until tender-crisp.', 'Heat remaining olive oil in a pan and brown the ground turkey.', 'Season turkey with garlic powder, paprika, salt, and pepper.', 'Assemble bowl: quinoa base, turkey, sweet potato, and broccoli.'],
    10, 25, 1,
    560, 42, 58, 14, 8,
    ARRAY['high_protein', 'high_fiber', 'gluten_free', 'dairy_free'],
    ARRAY['build_muscle', 'maintain']
),
(
    'b0000000-0000-0000-0000-000000000004',
    'Salmon Rice Bowl',
    'lunch',
    'Pan-seared salmon fillet on a bed of jasmine rice with edamame, avocado slices, and soy-ginger dressing.',
    '[{"name": "salmon fillet", "amount": 150, "unit": "g"}, {"name": "jasmine rice (dry)", "amount": 75, "unit": "g"}, {"name": "edamame (shelled)", "amount": 60, "unit": "g"}, {"name": "avocado", "amount": 0.25, "unit": "whole"}, {"name": "soy sauce (low sodium)", "amount": 15, "unit": "ml"}, {"name": "fresh ginger (grated)", "amount": 5, "unit": "g"}, {"name": "sesame oil", "amount": 5, "unit": "ml"}, {"name": "sesame seeds", "amount": 5, "unit": "g"}, {"name": "green onion", "amount": 10, "unit": "g"}]'::jsonb,
    ARRAY['Cook jasmine rice according to package directions.', 'Season salmon with salt and pepper.', 'Heat sesame oil in a pan over medium-high heat and sear salmon skin-side down for 4 minutes.', 'Flip and cook another 3 minutes until just cooked through.', 'Boil edamame for 3 minutes and drain.', 'Mix soy sauce and grated ginger for the dressing.', 'Assemble bowl: rice, salmon (flaked or whole), edamame, and avocado slices.', 'Drizzle with soy-ginger dressing and garnish with sesame seeds and green onion.'],
    10, 15, 1,
    580, 40, 52, 22, 5,
    ARRAY['high_protein', 'dairy_free'],
    ARRAY['build_muscle', 'general_health']
),
(
    'b0000000-0000-0000-0000-000000000005',
    'Chicken Stir-Fry',
    'lunch',
    'Quick stir-fried chicken with colorful bell peppers, snap peas, and a savory garlic-soy sauce served over rice.',
    '[{"name": "chicken breast", "amount": 170, "unit": "g"}, {"name": "jasmine rice (dry)", "amount": 70, "unit": "g"}, {"name": "red bell pepper", "amount": 60, "unit": "g"}, {"name": "yellow bell pepper", "amount": 60, "unit": "g"}, {"name": "snap peas", "amount": 60, "unit": "g"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "soy sauce (low sodium)", "amount": 20, "unit": "ml"}, {"name": "sesame oil", "amount": 5, "unit": "ml"}, {"name": "cornstarch", "amount": 5, "unit": "g"}, {"name": "vegetable oil", "amount": 10, "unit": "ml"}]'::jsonb,
    ARRAY['Cook rice according to package directions.', 'Slice chicken into thin strips and toss with cornstarch.', 'Heat vegetable oil in a wok or large pan over high heat.', 'Stir-fry chicken strips for 4-5 minutes until golden, then set aside.', 'Add sliced peppers and snap peas to the wok and cook for 2-3 minutes.', 'Return chicken to the wok, add minced garlic and soy sauce.', 'Drizzle sesame oil and toss everything together for 1 minute.', 'Serve the stir-fry over rice.'],
    10, 12, 1,
    520, 40, 56, 12, 4,
    ARRAY['high_protein', 'dairy_free', 'quick'],
    ARRAY['build_muscle', 'maintain']
),
(
    'b0000000-0000-0000-0000-000000000006',
    'Lentil Soup',
    'lunch',
    'Hearty and warming red lentil soup simmered with carrots, celery, onion, and cumin.',
    '[{"name": "red lentils (dry)", "amount": 100, "unit": "g"}, {"name": "carrot", "amount": 80, "unit": "g"}, {"name": "celery", "amount": 60, "unit": "g"}, {"name": "onion", "amount": 80, "unit": "g"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "vegetable broth", "amount": 500, "unit": "ml"}, {"name": "olive oil", "amount": 10, "unit": "ml"}, {"name": "ground cumin", "amount": 3, "unit": "g"}, {"name": "turmeric", "amount": 1, "unit": "g"}, {"name": "lemon juice", "amount": 15, "unit": "ml"}, {"name": "salt", "amount": 2, "unit": "g"}]'::jsonb,
    ARRAY['Dice onion, carrot, and celery.', 'Heat olive oil in a large pot over medium heat and saute onion for 3 minutes.', 'Add carrot, celery, and garlic and cook another 2 minutes.', 'Stir in cumin and turmeric until fragrant.', 'Add rinsed lentils and vegetable broth, bring to a boil.', 'Reduce heat and simmer for 20 minutes until lentils are tender.', 'Squeeze in lemon juice, season with salt, and blend partially for a creamy texture.'],
    10, 25, 2,
    280, 16, 38, 6, 10,
    ARRAY['high_fiber', 'high_protein', 'vegetarian', 'vegan', 'dairy_free', 'gluten_free'],
    ARRAY['lose_weight', 'general_health']
),
(
    'b0000000-0000-0000-0000-000000000007',
    'Chicken Burrito Bowl',
    'lunch',
    'A Tex-Mex bowl with seasoned chicken, black beans, rice, corn, salsa, and a dollop of sour cream.',
    '[{"name": "chicken breast", "amount": 170, "unit": "g"}, {"name": "brown rice (dry)", "amount": 65, "unit": "g"}, {"name": "black beans (canned, drained)", "amount": 80, "unit": "g"}, {"name": "corn kernels", "amount": 50, "unit": "g"}, {"name": "salsa", "amount": 50, "unit": "g"}, {"name": "sour cream", "amount": 20, "unit": "g"}, {"name": "lime", "amount": 0.5, "unit": "whole"}, {"name": "chili powder", "amount": 3, "unit": "g"}, {"name": "cumin", "amount": 2, "unit": "g"}, {"name": "olive oil", "amount": 5, "unit": "ml"}]'::jsonb,
    ARRAY['Cook brown rice according to package directions.', 'Season chicken breast with chili powder, cumin, salt, and pepper.', 'Heat olive oil in a pan and cook chicken for 6-7 minutes per side until done.', 'Rest chicken for 3 minutes, then slice.', 'Warm black beans and corn in a small pan.', 'Assemble bowl: rice, sliced chicken, black beans, corn, and salsa.', 'Top with a dollop of sour cream and a squeeze of lime.'],
    10, 18, 1,
    560, 44, 60, 14, 9,
    ARRAY['high_protein', 'high_fiber', 'gluten_free'],
    ARRAY['build_muscle', 'maintain']
),
(
    'b0000000-0000-0000-0000-000000000008',
    'Mediterranean Bowl',
    'lunch',
    'A vibrant bowl of falafel over couscous with hummus, cucumber, cherry tomatoes, and tzatziki.',
    '[{"name": "falafel (baked, store-bought)", "amount": 4, "unit": "pieces"}, {"name": "couscous (dry)", "amount": 70, "unit": "g"}, {"name": "hummus", "amount": 40, "unit": "g"}, {"name": "cucumber", "amount": 60, "unit": "g"}, {"name": "cherry tomatoes", "amount": 60, "unit": "g"}, {"name": "red onion", "amount": 20, "unit": "g"}, {"name": "tzatziki", "amount": 30, "unit": "g"}, {"name": "olive oil", "amount": 5, "unit": "ml"}, {"name": "fresh parsley", "amount": 5, "unit": "g"}, {"name": "lemon juice", "amount": 10, "unit": "ml"}]'::jsonb,
    ARRAY['Prepare couscous by pouring boiling water over it, cover, and let sit for 5 minutes, then fluff.', 'Bake falafel according to package directions (usually 12-15 minutes at 200C).', 'Dice cucumber, halve cherry tomatoes, and thinly slice red onion.', 'Arrange couscous in a bowl and top with falafel.', 'Add cucumber, tomatoes, and red onion around the bowl.', 'Add a dollop of hummus and tzatziki.', 'Drizzle with olive oil and lemon juice, garnish with parsley.'],
    10, 15, 1,
    490, 18, 58, 20, 7,
    ARRAY['high_fiber', 'vegetarian'],
    ARRAY['general_health', 'maintain']
);

-- ---- DINNER (8) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'c0000000-0000-0000-0000-000000000001',
    'Baked Salmon & Vegetables',
    'dinner',
    'Oven-baked salmon fillet with roasted asparagus, cherry tomatoes, and a lemon-dill butter sauce.',
    '[{"name": "salmon fillet", "amount": 180, "unit": "g"}, {"name": "asparagus", "amount": 120, "unit": "g"}, {"name": "cherry tomatoes", "amount": 80, "unit": "g"}, {"name": "olive oil", "amount": 10, "unit": "ml"}, {"name": "butter", "amount": 10, "unit": "g"}, {"name": "lemon", "amount": 0.5, "unit": "whole"}, {"name": "fresh dill", "amount": 5, "unit": "g"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Preheat oven to 200C / 400F.', 'Trim asparagus and halve cherry tomatoes, toss with olive oil, salt, and pepper.', 'Place salmon fillet on a baking tray lined with parchment paper.', 'Arrange vegetables around the salmon.', 'Melt butter with minced garlic, lemon juice, and chopped dill.', 'Drizzle the lemon-dill butter over the salmon.', 'Bake for 15-18 minutes until salmon is flaky and vegetables are tender.', 'Serve with a lemon wedge.'],
    10, 18, 1,
    420, 40, 10, 24, 4,
    ARRAY['high_protein', 'low_carb', 'gluten_free'],
    ARRAY['lose_weight', 'general_health']
),
(
    'c0000000-0000-0000-0000-000000000002',
    'Chicken Breast & Sweet Potato',
    'dinner',
    'Juicy pan-seared chicken breast paired with roasted sweet potato wedges and steamed green beans.',
    '[{"name": "chicken breast", "amount": 200, "unit": "g"}, {"name": "sweet potato", "amount": 200, "unit": "g"}, {"name": "green beans", "amount": 100, "unit": "g"}, {"name": "olive oil", "amount": 10, "unit": "ml"}, {"name": "garlic powder", "amount": 2, "unit": "g"}, {"name": "smoked paprika", "amount": 2, "unit": "g"}, {"name": "dried oregano", "amount": 1, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "black pepper", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Preheat oven to 200C / 400F.', 'Cut sweet potato into wedges, toss with half the olive oil, paprika, and salt.', 'Roast sweet potato wedges for 25 minutes, flipping halfway.', 'Season chicken breast with garlic powder, oregano, salt, and pepper.', 'Heat remaining olive oil in a pan and cook chicken for 6-7 minutes per side.', 'Steam green beans for 4-5 minutes until tender-crisp.', 'Slice chicken and serve with sweet potato wedges and green beans.'],
    10, 25, 1,
    500, 46, 44, 14, 7,
    ARRAY['high_protein', 'high_fiber', 'gluten_free', 'dairy_free'],
    ARRAY['build_muscle', 'maintain']
),
(
    'c0000000-0000-0000-0000-000000000003',
    'Lean Beef Stir-Fry',
    'dinner',
    'Thinly sliced lean beef stir-fried with broccoli, carrots, and snow peas in a savory oyster sauce.',
    '[{"name": "lean beef sirloin", "amount": 180, "unit": "g"}, {"name": "broccoli florets", "amount": 100, "unit": "g"}, {"name": "carrot", "amount": 60, "unit": "g"}, {"name": "snow peas", "amount": 60, "unit": "g"}, {"name": "oyster sauce", "amount": 20, "unit": "ml"}, {"name": "soy sauce (low sodium)", "amount": 10, "unit": "ml"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "fresh ginger", "amount": 5, "unit": "g"}, {"name": "vegetable oil", "amount": 10, "unit": "ml"}, {"name": "cornstarch", "amount": 5, "unit": "g"}]'::jsonb,
    ARRAY['Slice beef thinly against the grain and toss with cornstarch.', 'Slice carrot into thin rounds and trim snow peas.', 'Heat vegetable oil in a wok over high heat until smoking.', 'Stir-fry beef for 2-3 minutes until browned, then set aside.', 'Add broccoli, carrot, and snow peas to the wok and cook for 3 minutes.', 'Return beef to the wok, add minced garlic and grated ginger.', 'Pour in oyster sauce and soy sauce, toss everything together for 1 minute.', 'Serve immediately with rice if desired.'],
    15, 10, 1,
    400, 40, 18, 18, 5,
    ARRAY['high_protein', 'low_carb', 'dairy_free'],
    ARRAY['lose_weight', 'build_muscle']
),
(
    'c0000000-0000-0000-0000-000000000004',
    'Shrimp Pasta',
    'dinner',
    'Garlic shrimp tossed with whole-wheat penne in a light olive oil and cherry tomato sauce with fresh basil.',
    '[{"name": "shrimp (peeled, deveined)", "amount": 160, "unit": "g"}, {"name": "whole-wheat penne", "amount": 80, "unit": "g"}, {"name": "cherry tomatoes", "amount": 100, "unit": "g"}, {"name": "garlic cloves", "amount": 3, "unit": "cloves"}, {"name": "olive oil", "amount": 15, "unit": "ml"}, {"name": "white wine", "amount": 30, "unit": "ml"}, {"name": "fresh basil", "amount": 8, "unit": "g"}, {"name": "red pepper flakes", "amount": 1, "unit": "pinch"}, {"name": "salt", "amount": 1, "unit": "pinch"}, {"name": "parmesan cheese", "amount": 10, "unit": "g"}]'::jsonb,
    ARRAY['Cook penne in salted boiling water until al dente, then drain reserving some pasta water.', 'Heat olive oil in a large pan over medium-high heat.', 'Add minced garlic and red pepper flakes, cook for 30 seconds.', 'Add shrimp and cook 2 minutes per side until pink.', 'Halve cherry tomatoes, add to the pan with white wine.', 'Cook for 2-3 minutes until tomatoes soften.', 'Toss in the cooked penne with a splash of pasta water.', 'Remove from heat, top with torn basil and grated parmesan.'],
    10, 15, 1,
    510, 36, 52, 16, 6,
    ARRAY['high_protein'],
    ARRAY['maintain', 'general_health']
),
(
    'c0000000-0000-0000-0000-000000000005',
    'Turkey Meatballs & Zucchini Noodles',
    'dinner',
    'Lean turkey meatballs baked until golden, served over spiralized zucchini noodles with marinara sauce.',
    '[{"name": "ground turkey (93% lean)", "amount": 180, "unit": "g"}, {"name": "zucchini", "amount": 250, "unit": "g"}, {"name": "marinara sauce", "amount": 120, "unit": "ml"}, {"name": "egg", "amount": 1, "unit": "small"}, {"name": "breadcrumbs", "amount": 15, "unit": "g"}, {"name": "garlic powder", "amount": 2, "unit": "g"}, {"name": "dried Italian herbs", "amount": 3, "unit": "g"}, {"name": "olive oil", "amount": 5, "unit": "ml"}, {"name": "parmesan cheese", "amount": 10, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Preheat oven to 200C / 400F.', 'Mix ground turkey with egg, breadcrumbs, garlic powder, Italian herbs, and salt.', 'Form mixture into 8-10 small meatballs and place on a lined baking sheet.', 'Bake meatballs for 18-20 minutes until cooked through.', 'Spiralize the zucchini into noodles.', 'Heat olive oil in a pan and saute zucchini noodles for 2-3 minutes.', 'Warm marinara sauce in a small pot.', 'Plate zucchini noodles, top with meatballs and marinara, and finish with parmesan.'],
    15, 20, 1,
    380, 40, 18, 16, 4,
    ARRAY['high_protein', 'low_carb'],
    ARRAY['lose_weight', 'build_muscle']
),
(
    'c0000000-0000-0000-0000-000000000006',
    'Grilled Fish Tacos',
    'dinner',
    'Grilled white fish fillets in charred corn tortillas with shredded cabbage, mango salsa, and lime crema.',
    '[{"name": "white fish fillet (cod or tilapia)", "amount": 170, "unit": "g"}, {"name": "corn tortillas (small)", "amount": 3, "unit": "pieces"}, {"name": "red cabbage (shredded)", "amount": 60, "unit": "g"}, {"name": "mango", "amount": 60, "unit": "g"}, {"name": "red onion", "amount": 20, "unit": "g"}, {"name": "cilantro", "amount": 8, "unit": "g"}, {"name": "lime", "amount": 1, "unit": "whole"}, {"name": "sour cream", "amount": 20, "unit": "g"}, {"name": "olive oil", "amount": 5, "unit": "ml"}, {"name": "chili powder", "amount": 2, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Season fish with chili powder, salt, and a squeeze of lime.', 'Brush fish with olive oil and grill on medium-high for 3-4 minutes per side.', 'Dice mango, red onion, and cilantro for the salsa, toss with lime juice.', 'Mix sour cream with a squeeze of lime juice for the crema.', 'Char corn tortillas briefly on each side over an open flame or dry pan.', 'Flake the grilled fish into large pieces.', 'Assemble tacos: tortilla, shredded cabbage, fish, mango salsa, and a drizzle of lime crema.'],
    15, 10, 1,
    420, 36, 38, 14, 5,
    ARRAY['high_protein', 'gluten_free'],
    ARRAY['lose_weight', 'general_health']
),
(
    'c0000000-0000-0000-0000-000000000007',
    'Chicken Curry & Rice',
    'dinner',
    'Tender chicken pieces simmered in a creamy coconut curry sauce with chickpeas, served over basmati rice.',
    '[{"name": "chicken breast", "amount": 180, "unit": "g"}, {"name": "basmati rice (dry)", "amount": 75, "unit": "g"}, {"name": "coconut milk (light)", "amount": 120, "unit": "ml"}, {"name": "chickpeas (canned, drained)", "amount": 60, "unit": "g"}, {"name": "onion", "amount": 60, "unit": "g"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "curry powder", "amount": 8, "unit": "g"}, {"name": "tomato paste", "amount": 15, "unit": "g"}, {"name": "vegetable oil", "amount": 10, "unit": "ml"}, {"name": "fresh cilantro", "amount": 5, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Cook basmati rice according to package directions.', 'Dice chicken into bite-sized pieces, season with salt and half the curry powder.', 'Heat oil in a deep pan over medium heat and cook diced onion for 3 minutes.', 'Add garlic and remaining curry powder, cook for 1 minute until fragrant.', 'Add chicken pieces and sear for 3-4 minutes on each side.', 'Stir in tomato paste, coconut milk, and chickpeas.', 'Simmer for 12-15 minutes until chicken is cooked and sauce thickens.', 'Serve curry over rice and garnish with cilantro.'],
    10, 25, 1,
    600, 44, 58, 18, 6,
    ARRAY['high_protein', 'dairy_free', 'gluten_free'],
    ARRAY['build_muscle', 'maintain']
),
(
    'c0000000-0000-0000-0000-000000000008',
    'Tofu Stir-Fry',
    'dinner',
    'Crispy pan-fried tofu with bok choy, bell peppers, and cashews in a sweet and savory teriyaki glaze.',
    '[{"name": "firm tofu", "amount": 200, "unit": "g"}, {"name": "bok choy", "amount": 120, "unit": "g"}, {"name": "red bell pepper", "amount": 60, "unit": "g"}, {"name": "cashews", "amount": 20, "unit": "g"}, {"name": "soy sauce (low sodium)", "amount": 20, "unit": "ml"}, {"name": "rice vinegar", "amount": 10, "unit": "ml"}, {"name": "honey", "amount": 10, "unit": "g"}, {"name": "cornstarch", "amount": 10, "unit": "g"}, {"name": "sesame oil", "amount": 5, "unit": "ml"}, {"name": "garlic cloves", "amount": 2, "unit": "cloves"}, {"name": "fresh ginger", "amount": 5, "unit": "g"}]'::jsonb,
    ARRAY['Press tofu for 15 minutes to remove excess moisture, then cut into cubes.', 'Toss tofu cubes in cornstarch until evenly coated.', 'Heat sesame oil in a wok or large pan over high heat.', 'Pan-fry tofu cubes for 5-6 minutes, turning occasionally, until crispy on all sides.', 'Remove tofu and add sliced bell pepper and halved bok choy to the wok.', 'Stir-fry vegetables for 3 minutes.', 'Mix soy sauce, rice vinegar, honey, minced garlic, and grated ginger for the glaze.', 'Return tofu to the wok, pour in the glaze, and toss to coat.', 'Top with cashews and serve.'],
    20, 12, 1,
    360, 22, 28, 18, 4,
    ARRAY['vegetarian', 'vegan', 'dairy_free'],
    ARRAY['lose_weight', 'general_health']
);

-- ---- SNACK (7) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'd0000000-0000-0000-0000-000000000001',
    'Protein Shake',
    'snack',
    'A quick and creamy whey protein shake blended with milk and a banana for a fast post-workout refuel.',
    '[{"name": "whey protein powder", "amount": 30, "unit": "g"}, {"name": "whole milk", "amount": 250, "unit": "ml"}, {"name": "banana", "amount": 0.5, "unit": "medium"}, {"name": "ice cubes", "amount": 4, "unit": "pieces"}]'::jsonb,
    ARRAY['Add milk, protein powder, banana, and ice to a blender.', 'Blend on high for 30-45 seconds until smooth.', 'Pour into a glass and serve immediately.'],
    3, 0, 1,
    280, 30, 28, 6, 1,
    ARRAY['high_protein', 'quick', 'gluten_free'],
    ARRAY['build_muscle', 'maintain']
),
(
    'd0000000-0000-0000-0000-000000000002',
    'Greek Yogurt & Berries',
    'snack',
    'Thick Greek yogurt topped with a handful of mixed berries and a sprinkle of flax seeds.',
    '[{"name": "Greek yogurt (0% fat)", "amount": 170, "unit": "g"}, {"name": "mixed berries", "amount": 80, "unit": "g"}, {"name": "flax seeds", "amount": 8, "unit": "g"}]'::jsonb,
    ARRAY['Spoon Greek yogurt into a bowl.', 'Top with mixed berries.', 'Sprinkle flax seeds on top and serve.'],
    3, 0, 1,
    170, 18, 16, 4, 3,
    ARRAY['high_protein', 'low_fat', 'quick', 'gluten_free', 'vegetarian'],
    ARRAY['lose_weight', 'general_health']
),
(
    'd0000000-0000-0000-0000-000000000003',
    'Apple & Peanut Butter',
    'snack',
    'Crisp apple slices served with a generous portion of natural peanut butter for dipping.',
    '[{"name": "apple", "amount": 1, "unit": "medium"}, {"name": "natural peanut butter", "amount": 25, "unit": "g"}]'::jsonb,
    ARRAY['Wash and slice the apple into wedges, removing the core.', 'Serve with peanut butter on the side for dipping.'],
    3, 0, 1,
    250, 7, 30, 14, 5,
    ARRAY['quick', 'vegetarian', 'vegan', 'gluten_free', 'dairy_free'],
    ARRAY['general_health', 'maintain']
),
(
    'd0000000-0000-0000-0000-000000000004',
    'Cottage Cheese & Fruit',
    'snack',
    'Low-fat cottage cheese topped with pineapple chunks and a light dusting of cinnamon.',
    '[{"name": "cottage cheese (low-fat)", "amount": 150, "unit": "g"}, {"name": "pineapple chunks", "amount": 80, "unit": "g"}, {"name": "cinnamon", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Spoon cottage cheese into a bowl.', 'Top with pineapple chunks.', 'Dust with cinnamon and serve.'],
    3, 0, 1,
    160, 18, 16, 2, 1,
    ARRAY['high_protein', 'low_fat', 'quick', 'gluten_free', 'vegetarian'],
    ARRAY['lose_weight', 'maintain']
),
(
    'd0000000-0000-0000-0000-000000000005',
    'Handful of Almonds',
    'snack',
    'A simple and satisfying portion of raw almonds packed with healthy fats and vitamin E.',
    '[{"name": "raw almonds", "amount": 30, "unit": "g"}]'::jsonb,
    ARRAY['Measure out a 30g portion of almonds.', 'Enjoy as a quick on-the-go snack.'],
    1, 0, 1,
    175, 6, 6, 15, 4,
    ARRAY['quick', 'vegetarian', 'vegan', 'gluten_free', 'dairy_free'],
    ARRAY['general_health', 'maintain']
),
(
    'd0000000-0000-0000-0000-000000000006',
    'Rice Cakes & Avocado',
    'snack',
    'Light rice cakes topped with smashed avocado, a squeeze of lemon, and everything bagel seasoning.',
    '[{"name": "rice cakes", "amount": 2, "unit": "pieces"}, {"name": "avocado", "amount": 0.5, "unit": "whole"}, {"name": "lemon juice", "amount": 5, "unit": "ml"}, {"name": "everything bagel seasoning", "amount": 3, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Mash the avocado in a small bowl with lemon juice and salt.', 'Spread the avocado evenly on the rice cakes.', 'Sprinkle everything bagel seasoning on top.'],
    3, 0, 1,
    210, 4, 22, 13, 5,
    ARRAY['quick', 'vegetarian', 'vegan', 'dairy_free', 'gluten_free'],
    ARRAY['general_health', 'maintain']
),
(
    'd0000000-0000-0000-0000-000000000007',
    'Protein Bar',
    'snack',
    'A homemade no-bake protein bar with oats, protein powder, honey, and dark chocolate chips.',
    '[{"name": "rolled oats", "amount": 30, "unit": "g"}, {"name": "whey protein powder", "amount": 20, "unit": "g"}, {"name": "natural peanut butter", "amount": 20, "unit": "g"}, {"name": "honey", "amount": 15, "unit": "g"}, {"name": "dark chocolate chips", "amount": 10, "unit": "g"}]'::jsonb,
    ARRAY['Mix oats, protein powder, and chocolate chips in a bowl.', 'Add peanut butter and honey, stir until a thick dough forms.', 'Press mixture into a small rectangular container lined with parchment.', 'Refrigerate for at least 1 hour until firm.', 'Cut into bars and store in the fridge.'],
    10, 0, 2,
    210, 14, 24, 8, 2,
    ARRAY['high_protein', 'vegetarian'],
    ARRAY['build_muscle', 'maintain']
);

-- ---- SHAKE (2) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'e0000000-0000-0000-0000-000000000001',
    'Mass Gainer Shake',
    'shake',
    'A calorie-dense shake with whey protein, oats, banana, peanut butter, and whole milk for muscle building.',
    '[{"name": "whey protein powder", "amount": 40, "unit": "g"}, {"name": "rolled oats", "amount": 50, "unit": "g"}, {"name": "banana", "amount": 1, "unit": "medium"}, {"name": "natural peanut butter", "amount": 30, "unit": "g"}, {"name": "whole milk", "amount": 300, "unit": "ml"}, {"name": "honey", "amount": 10, "unit": "g"}, {"name": "ice cubes", "amount": 4, "unit": "pieces"}]'::jsonb,
    ARRAY['Add oats to the blender and pulse into a rough flour.', 'Add milk, protein powder, banana, peanut butter, and honey.', 'Add ice cubes and blend on high for 45-60 seconds until smooth.', 'Pour into a large glass or shaker bottle and serve.'],
    5, 0, 1,
    720, 48, 74, 24, 6,
    ARRAY['high_protein', 'vegetarian'],
    ARRAY['build_muscle']
),
(
    'e0000000-0000-0000-0000-000000000002',
    'Green Smoothie',
    'shake',
    'A refreshing nutrient-packed green smoothie with spinach, banana, mango, and almond milk.',
    '[{"name": "fresh spinach", "amount": 60, "unit": "g"}, {"name": "banana", "amount": 0.5, "unit": "medium"}, {"name": "frozen mango chunks", "amount": 80, "unit": "g"}, {"name": "almond milk (unsweetened)", "amount": 250, "unit": "ml"}, {"name": "chia seeds", "amount": 10, "unit": "g"}, {"name": "lime juice", "amount": 5, "unit": "ml"}]'::jsonb,
    ARRAY['Add almond milk and spinach to the blender and blend until smooth.', 'Add banana, mango, chia seeds, and lime juice.', 'Blend on high for 30-45 seconds until creamy.', 'Pour into a glass and serve immediately.'],
    5, 0, 1,
    190, 6, 32, 5, 7,
    ARRAY['high_fiber', 'vegetarian', 'vegan', 'gluten_free', 'dairy_free', 'quick'],
    ARRAY['lose_weight', 'general_health']
);

-- ---- DESSERT (2) ----

INSERT INTO public.recipes (id, name, category, description, ingredients, instructions, prep_time_min, cook_time_min, servings, calories_per_serving, protein_g_per_serving, carbs_g_per_serving, fat_g_per_serving, fiber_g_per_serving, tags, goal_types)
VALUES
(
    'f0000000-0000-0000-0000-000000000001',
    'Protein Brownie',
    'dessert',
    'Fudgy chocolate brownies made with black beans and protein powder for a guilt-free dessert.',
    '[{"name": "black beans (canned, drained)", "amount": 200, "unit": "g"}, {"name": "whey protein powder (chocolate)", "amount": 30, "unit": "g"}, {"name": "cocoa powder", "amount": 20, "unit": "g"}, {"name": "egg", "amount": 2, "unit": "large"}, {"name": "honey", "amount": 40, "unit": "g"}, {"name": "coconut oil (melted)", "amount": 15, "unit": "ml"}, {"name": "vanilla extract", "amount": 5, "unit": "ml"}, {"name": "baking powder", "amount": 3, "unit": "g"}, {"name": "dark chocolate chips", "amount": 20, "unit": "g"}, {"name": "salt", "amount": 1, "unit": "pinch"}]'::jsonb,
    ARRAY['Preheat oven to 180C / 350F.', 'Rinse and drain black beans thoroughly.', 'Blend beans, eggs, honey, coconut oil, and vanilla in a food processor until smooth.', 'Add protein powder, cocoa powder, baking powder, and salt, then blend again.', 'Fold in chocolate chips by hand.', 'Pour batter into a greased 8x8 inch baking pan.', 'Bake for 20-22 minutes until a toothpick comes out mostly clean.', 'Let cool for 10 minutes before cutting into 4 pieces.'],
    10, 22, 4,
    240, 14, 30, 8, 5,
    ARRAY['high_protein', 'high_fiber', 'gluten_free', 'vegetarian'],
    ARRAY['build_muscle', 'maintain']
),
(
    'f0000000-0000-0000-0000-000000000002',
    'Frozen Yogurt Bark',
    'dessert',
    'A light frozen treat made from Greek yogurt spread thin with mixed berries, granola, and a honey drizzle.',
    '[{"name": "Greek yogurt (0% fat)", "amount": 300, "unit": "g"}, {"name": "mixed berries", "amount": 100, "unit": "g"}, {"name": "granola", "amount": 30, "unit": "g"}, {"name": "honey", "amount": 15, "unit": "g"}, {"name": "vanilla extract", "amount": 3, "unit": "ml"}]'::jsonb,
    ARRAY['Line a baking sheet with parchment paper.', 'Mix yogurt with vanilla extract and honey.', 'Spread the yogurt mixture evenly on the parchment to about 1cm thickness.', 'Scatter mixed berries and granola over the top, pressing them in slightly.', 'Freeze for at least 3 hours until completely solid.', 'Break into irregular bark pieces and store in a freezer bag.'],
    10, 0, 4,
    120, 10, 16, 2, 1,
    ARRAY['low_fat', 'high_protein', 'vegetarian', 'gluten_free'],
    ARRAY['lose_weight', 'general_health']
);

-- ============================================================================
-- 5. SEED DATA: MEAL PLAN TEMPLATES (12 total, 3 per goal type)
--    & MEAL PLAN ITEMS linking templates to recipes
-- ============================================================================

-- We use fixed UUIDs for templates as well.

-- ============================================================================
-- GOAL: lose_weight (3 templates, 1500-1800 cal, high protein ratio)
-- ============================================================================

-- Template 1: Lean & Clean Day (lose_weight)
-- Egg White Omelette (180 cal, 30P, 6C, 2F)
-- Grilled Chicken Salad (380 cal, 42P, 12C, 18F)
-- Baked Salmon & Vegetables (420 cal, 40P, 10C, 24F)
-- Greek Yogurt & Berries (170 cal, 18P, 16C, 4F)
-- Green Smoothie (190 cal, 6P, 32C, 5F)
-- Total: 1340 -- need to adjust servings
-- Let's do: Egg White Omelette x1 (180), Grilled Chicken Salad x1 (380), Baked Salmon & Veg x1 (420), Greek Yogurt & Berries x1 (170), Cottage Cheese & Fruit x1 (160), Green Smoothie x1 (190)
-- Total: 180+380+420+170+160+190 = 1500 cal, 30+42+40+18+18+6 = 154P, 6+12+10+16+16+32 = 92C, 2+18+24+4+2+5 = 55F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '10000000-0000-0000-0000-000000000001',
    'Lean & Clean Day',
    'A high-protein, low-calorie day focused on lean proteins, vegetables, and minimal processed foods.',
    'lose_weight',
    1500, 154, 92, 55,
    ARRAY['high_protein', 'low_fat']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('10000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'breakfast', 1, 1),
('10000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'lunch', 1, 2),
('10000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'dinner', 1, 3),
('10000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'snack', 1, 4),
('10000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000004', 'snack', 1, 5),
('10000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002', 'snack', 1, 6);

-- Template 2: Fat-Burning Focus (lose_weight)
-- Greek Yogurt Parfait x1 (310 cal, 22P, 42C, 5F)
-- Tuna Wrap x1 (350 cal, 38P, 30C, 8F)
-- Turkey Meatballs & Zucchini Noodles x1 (380 cal, 40P, 18C, 16F)
-- Cottage Cheese & Fruit x1 (160 cal, 18P, 16C, 2F)
-- Total: 310+350+380+160 = 1200 ... need more
-- Add: Apple & Peanut Butter x1 (250 cal, 7P, 30C, 14F)
-- Total: 1450 ... close to 1500
-- Let's use Greek Yogurt Parfait x1 (310), Tuna Wrap x1 (350), Grilled Fish Tacos x1 (420), Greek Yogurt & Berries x1 (170), Apple & Peanut Butter x1 (250)
-- Total: 310+350+420+170+250 = 1500, 22+38+36+18+7 = 121P, 42+30+38+16+30 = 156C, 5+8+14+4+14 = 45F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '10000000-0000-0000-0000-000000000002',
    'Fat-Burning Focus',
    'A calorie-controlled day plan featuring lean proteins and whole foods to maximize fat loss.',
    'lose_weight',
    1500, 121, 156, 45,
    ARRAY['high_protein', 'low_fat']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('10000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'breakfast', 1, 1),
('10000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'lunch', 1, 2),
('10000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000006', 'dinner', 1, 3),
('10000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'snack', 1, 4),
('10000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000003', 'snack', 1, 5);

-- Template 3: Light & Lean (lose_weight)
-- Overnight Oats x1 (340 cal, 12P, 52C, 9F)
-- Lentil Soup x1 (280 cal, 16P, 38C, 6F)
-- Lean Beef Stir-Fry x1 (400 cal, 40P, 18C, 18F)
-- Greek Yogurt & Berries x1 (170 cal, 18P, 16C, 4F)
-- Frozen Yogurt Bark x1 (120 cal, 10P, 16C, 2F)
-- Total: 340+280+400+170+120 = 1310 ... need more
-- Adjust: Lentil Soup x1.5 = (420 cal, 24P, 57C, 9F)
-- Total: 340+420+400+170+120 = 1450, 12+24+40+18+10 = 104P, 52+57+18+16+16 = 159C, 9+9+18+4+2 = 42F
-- Or simpler: Overnight Oats x1 (340), Lentil Soup x2 servings from 2-serving recipe (560 cal, 32P, 76C, 12F), Tofu Stir-Fry x1 (360, 22P, 28C, 18F), Frozen Yogurt Bark x1 (120, 10P, 16C, 2F)
-- Total: 340+560+360+120 = 1380 ... hmm
-- Let's use: Egg White Omelette x1 (180), Lentil Soup x2 (560), Tofu Stir-Fry x1 (360), Greek Yogurt & Berries x1 (170), Frozen Yogurt Bark x1 (120)
-- Total: 180+560+360+170+120 = 1390 ... still low
-- Better: Avocado Toast x1 (380), Lentil Soup x1 (280), Lean Beef Stir-Fry x1 (400), Tofu Stir-Fry x0 ...
-- Let's simplify: Overnight Oats x1 (340), Lentil Soup x1 (280), Lean Beef Stir-Fry x1 (400), Greek Yogurt & Berries x1 (170), Cottage Cheese & Fruit x1 (160), Green Smoothie x1 (190)
-- Total: 340+280+400+170+160+190 = 1540, 12+16+40+18+18+6 = 110P, 52+38+18+16+16+32 = 172C, 9+6+18+4+2+5 = 44F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '10000000-0000-0000-0000-000000000003',
    'Light & Lean',
    'A lighter day plan combining fiber-rich meals with lean protein snacks to keep you full on fewer calories.',
    'lose_weight',
    1540, 110, 172, 44,
    ARRAY['high_fiber', 'low_fat']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('10000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000004', 'breakfast', 1, 1),
('10000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000006', 'lunch', 1, 2),
('10000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'dinner', 1, 3),
('10000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000002', 'snack', 1, 4),
('10000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000004', 'snack', 1, 5),
('10000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000002', 'snack', 1, 6);

-- ============================================================================
-- GOAL: build_muscle (3 templates, 2500-3000 cal, high protein + carbs)
-- ============================================================================

-- Template 4: Muscle Builder Classic (build_muscle)
-- Protein Oats x1 (480 cal, 35P, 62C, 8F)
-- Turkey & Quinoa Bowl x1 (560 cal, 42P, 58C, 14F)
-- Chicken Curry & Rice x1 (600 cal, 44P, 58C, 18F)
-- Protein Shake x1 (280 cal, 30P, 28C, 6F)
-- Mass Gainer Shake x1 (720 cal, 48P, 74C, 24F)
-- Total: 480+560+600+280+720 = 2640, 35+42+44+30+48 = 199P, 62+58+58+28+74 = 280C, 8+14+18+6+24 = 70F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '20000000-0000-0000-0000-000000000001',
    'Muscle Builder Classic',
    'A high-calorie, high-protein day designed to fuel muscle growth with complex carbs and lean proteins.',
    'build_muscle',
    2640, 199, 280, 70,
    ARRAY['high_protein']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('20000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'breakfast', 1, 1),
('20000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000003', 'lunch', 1, 2),
('20000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000007', 'dinner', 1, 3),
('20000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'snack', 1, 4),
('20000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'snack', 1, 5);

-- Template 5: Power Bulk Day (build_muscle)
-- Protein Pancakes x1 (420 cal, 32P, 50C, 8F)
-- Chicken Burrito Bowl x1 (560 cal, 44P, 60C, 14F)
-- Chicken Breast & Sweet Potato x1 (500 cal, 46P, 44C, 14F)
-- Mass Gainer Shake x1 (720 cal, 48P, 74C, 24F)
-- Protein Bar x1 (210 cal, 14P, 24C, 8F)
-- Total: 420+560+500+720+210 = 2410 ... need more
-- Adjust: Protein Pancakes x1.5 => (630 cal, 48P, 75C, 12F)
-- Total: 630+560+500+720+210 = 2620, 48+44+46+48+14 = 200P, 75+60+44+74+24 = 277C, 12+14+14+24+8 = 72F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '20000000-0000-0000-0000-000000000002',
    'Power Bulk Day',
    'An energy-packed day with large portions and calorie-dense shakes to support serious weight training.',
    'build_muscle',
    2620, 200, 277, 72,
    ARRAY['high_protein']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('20000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000006', 'breakfast', 1.5, 1),
('20000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000007', 'lunch', 1, 2),
('20000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'dinner', 1, 3),
('20000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 'snack', 1, 4),
('20000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000007', 'snack', 1, 5);

-- Template 6: Strength Fuel (build_muscle)
-- Scrambled Eggs & Toast x1 (430 cal, 24P, 32C, 22F)
-- Salmon Rice Bowl x1 (580 cal, 40P, 52C, 22F)
-- Lean Beef Stir-Fry x1 (400 cal, 40P, 18C, 18F) + add rice via servings ... no, keep it simple
-- Actually: Chicken Stir-Fry x1 (520 cal, 40P, 56C, 12F)
-- Protein Shake x1 (280 cal, 30P, 28C, 6F)
-- Protein Bar x2 servings (420 cal, 28P, 48C, 16F)
-- Total: 430+580+520+280+420 = 2230 ... need more
-- Adjust: Scrambled Eggs & Toast x1.5 => (645 cal, 36P, 48C, 33F)
-- Total: 645+580+520+280+420 = 2445 ... still short
-- Better combo: Protein Oats x1 (480), Chicken Stir-Fry x1 (520), Chicken Breast & Sweet Potato x1.5 (750, 69P, 66C, 21F), Protein Shake x1 (280), Protein Brownie x1 (240)
-- Total: 480+520+750+280+240 = 2270 ... hmm
-- Let's go: Scrambled Eggs & Toast x2 (860, 48P, 64C, 44F), Salmon Rice Bowl x1 (580, 40P, 52C, 22F), Chicken Curry & Rice x1 (600, 44P, 58C, 18F), Protein Shake x2 (560, 60P, 56C, 12F)
-- Total: 860+580+600+560 = 2600, 48+40+44+60 = 192P, 64+52+58+56 = 230C, 44+22+18+12 = 96F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    'Strength Fuel',
    'A protein-heavy day with generous portions to fuel intense strength training sessions and recovery.',
    'build_muscle',
    2600, 192, 230, 96,
    ARRAY['high_protein']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('20000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000007', 'breakfast', 2, 1),
('20000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'lunch', 1, 2),
('20000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000007', 'dinner', 1, 3),
('20000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'snack', 2, 4);

-- ============================================================================
-- GOAL: maintain (3 templates, 2000-2200 cal, balanced)
-- ============================================================================

-- Template 7: Balanced Day (maintain)
-- Avocado Toast x1 (380 cal, 16P, 34C, 20F)
-- Chicken Stir-Fry x1 (520 cal, 40P, 56C, 12F)
-- Shrimp Pasta x1 (510 cal, 36P, 52C, 16F)
-- Apple & Peanut Butter x1 (250 cal, 7P, 30C, 14F)
-- Handful of Almonds x1 (175 cal, 6P, 6C, 15F)
-- Total: 380+520+510+250+175 = 1835 ... need more
-- Adjust: Avocado Toast x1 (380) + add Protein Shake x1 (280)
-- Total: 380+520+510+250+175+280 = 2115, 16+40+36+7+6+30 = 135P, 34+56+52+30+6+28 = 206C, 20+12+16+14+15+6 = 83F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '30000000-0000-0000-0000-000000000001',
    'Balanced Day',
    'A well-rounded day plan with balanced macros from whole foods to maintain your current weight and energy.',
    'maintain',
    2115, 135, 206, 83,
    ARRAY['high_protein']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('30000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', 'breakfast', 1, 1),
('30000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'lunch', 1, 2),
('30000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'dinner', 1, 3),
('30000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'snack', 1, 4),
('30000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000005', 'snack', 1, 5),
('30000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'snack', 1, 6);

-- Template 8: Steady State (maintain)
-- Greek Yogurt Parfait x1 (310 cal, 22P, 42C, 5F)
-- Turkey & Quinoa Bowl x1 (560 cal, 42P, 58C, 14F)
-- Grilled Fish Tacos x1 (420 cal, 36P, 38C, 14F)
-- Protein Bar x1 (210 cal, 14P, 24C, 8F)
-- Rice Cakes & Avocado x1 (210 cal, 4P, 22C, 13F)
-- Protein Brownie x1 (240 cal, 14P, 30C, 8F)
-- Total: 310+560+420+210+210+240 = 1950 ... close enough, or adjust
-- Better: add Cottage Cheese & Fruit x1 (160) and remove Protein Brownie
-- 310+560+420+210+210+160 = 1870 ... still short
-- Keep brownie: 310+560+420+210+210+240 = 1950
-- Let's adjust serving: Turkey Quinoa Bowl x1.1 => round to just using x1 and accepting 1950 ...
-- Actually let's pick higher cal recipes.
-- Protein Oats x1 (480), Mediterranean Bowl x1 (490), Chicken Curry & Rice x1 (600), Protein Bar x1 (210), Rice Cakes & Avocado x1 (210)
-- Total: 480+490+600+210+210 = 1990, 35+18+44+14+4 = 115P, 62+58+58+24+22 = 224C, 8+20+18+8+13 = 67F
-- Close to 2000, good for maintain

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '30000000-0000-0000-0000-000000000002',
    'Steady State',
    'A moderate-calorie day with satisfying meals that keep your energy stable throughout the day.',
    'maintain',
    1990, 115, 224, 67,
    ARRAY['high_fiber']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('30000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'breakfast', 1, 1),
('30000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000008', 'lunch', 1, 2),
('30000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000007', 'dinner', 1, 3),
('30000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000007', 'snack', 1, 4),
('30000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000006', 'snack', 1, 5);

-- Template 9: Everyday Balance (maintain)
-- Scrambled Eggs & Toast x1 (430 cal, 24P, 32C, 22F)
-- Chicken Burrito Bowl x1 (560 cal, 44P, 60C, 14F)
-- Shrimp Pasta x1 (510 cal, 36P, 52C, 16F)
-- Cottage Cheese & Fruit x1 (160 cal, 18P, 16C, 2F)
-- Handful of Almonds x1 (175 cal, 6P, 6C, 15F)
-- Total: 430+560+510+160+175 = 1835 ... let's add Frozen Yogurt Bark x1 (120)
-- Total: 430+560+510+160+175+120 = 1955, 24+44+36+18+6+10 = 138P, 32+60+52+16+6+16 = 182C, 22+14+16+2+15+2 = 71F
-- Or adjust: Scrambled Eggs & Toast x1 (430), Salmon Rice Bowl x1 (580), Turkey Meatballs & Zucchini Noodles x1 (380), Protein Shake x1 (280), Handful of Almonds x1 (175), Frozen Yogurt Bark x1 (120)
-- Total: 430+580+380+280+175+120 = 1965, 24+40+40+30+6+10 = 150P, 32+52+18+28+6+16 = 152C, 22+22+16+6+15+2 = 83F
-- Closer to 2000 and well balanced

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '30000000-0000-0000-0000-000000000003',
    'Everyday Balance',
    'A practical daily plan mixing familiar meals that hit maintenance calories with solid protein intake.',
    'maintain',
    1965, 150, 152, 83,
    ARRAY['high_protein']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('30000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000007', 'breakfast', 1, 1),
('30000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'lunch', 1, 2),
('30000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000005', 'dinner', 1, 3),
('30000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'snack', 1, 4),
('30000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000005', 'snack', 1, 5),
('30000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000002', 'snack', 1, 6);

-- ============================================================================
-- GOAL: general_health (3 templates, 1800-2200 cal, balanced, whole foods)
-- ============================================================================

-- Template 10: Whole Foods Day (general_health)
-- Overnight Oats x1 (340 cal, 12P, 52C, 9F)
-- Lentil Soup x1 (280 cal, 16P, 38C, 6F)
-- Baked Salmon & Vegetables x1 (420 cal, 40P, 10C, 24F)
-- Apple & Peanut Butter x1 (250 cal, 7P, 30C, 14F)
-- Green Smoothie x1 (190 cal, 6P, 32C, 5F)
-- Handful of Almonds x1 (175 cal, 6P, 6C, 15F)
-- Total: 340+280+420+250+190+175 = 1655 ... need more
-- Adjust: Lentil Soup x2 (560, 32P, 76C, 12F)
-- Total: 340+560+420+250+190+175 = 1935, 12+32+40+7+6+6 = 103P, 52+76+10+30+32+6 = 206C, 9+12+24+14+5+15 = 79F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '40000000-0000-0000-0000-000000000001',
    'Whole Foods Day',
    'A nutrient-dense day built entirely around whole, minimally processed foods with plenty of fiber.',
    'general_health',
    1935, 103, 206, 79,
    ARRAY['high_fiber', 'dairy_free']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('40000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000004', 'breakfast', 1, 1),
('40000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000006', 'lunch', 2, 2),
('40000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'dinner', 1, 3),
('40000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'snack', 1, 4),
('40000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002', 'snack', 1, 5),
('40000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000005', 'snack', 1, 6);

-- Template 11: Nourish & Thrive (general_health)
-- Avocado Toast x1 (380 cal, 16P, 34C, 20F)
-- Mediterranean Bowl x1 (490 cal, 18P, 58C, 20F)
-- Tofu Stir-Fry x1 (360 cal, 22P, 28C, 18F)
-- Greek Yogurt & Berries x1 (170 cal, 18P, 16C, 4F)
-- Rice Cakes & Avocado x1 (210 cal, 4P, 22C, 13F)
-- Frozen Yogurt Bark x1 (120 cal, 10P, 16C, 2F)
-- Total: 380+490+360+170+210+120 = 1730 ... need more
-- Adjust: Avocado Toast x1 (380), Mediterranean Bowl x1 (490), Chicken Curry & Rice x1 (600), Greek Yogurt & Berries x1 (170), Green Smoothie x1 (190)
-- Total: 380+490+600+170+190 = 1830, 16+18+44+18+6 = 102P, 34+58+58+16+32 = 198C, 20+20+18+4+5 = 67F

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '40000000-0000-0000-0000-000000000002',
    'Nourish & Thrive',
    'A plant-forward day with diverse whole foods, healthy fats, and plenty of colorful vegetables.',
    'general_health',
    1830, 102, 198, 67,
    ARRAY['high_fiber', 'vegetarian']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('40000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005', 'breakfast', 1, 1),
('40000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000008', 'lunch', 1, 2),
('40000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000007', 'dinner', 1, 3),
('40000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'snack', 1, 4),
('40000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'snack', 1, 5);

-- Template 12: Vitality Mix (general_health)
-- Greek Yogurt Parfait x1 (310 cal, 22P, 42C, 5F)
-- Salmon Rice Bowl x1 (580 cal, 40P, 52C, 22F)
-- Grilled Fish Tacos x1 (420 cal, 36P, 38C, 14F)
-- Cottage Cheese & Fruit x1 (160 cal, 18P, 16C, 2F)
-- Handful of Almonds x1 (175 cal, 6P, 6C, 15F)
-- Frozen Yogurt Bark x1 (120 cal, 10P, 16C, 2F)
-- Total: 310+580+420+160+175+120 = 1765 ... let's bump
-- Replace Greek Yogurt Parfait with Protein Pancakes x1 (420, 32P, 50C, 8F)
-- Total: 420+580+420+160+175+120 = 1875, 32+40+36+18+6+10 = 142P, 50+52+38+16+6+16 = 178C, 8+22+14+2+15+2 = 63F
-- Still a touch low, let's add Green Smoothie x1 (190): total 2065, 148P, 210C, 68F
-- That's solid for general_health

INSERT INTO public.meal_plan_templates (id, name, description, goal_type, total_calories, total_protein_g, total_carbs_g, total_fat_g, tags)
VALUES (
    '40000000-0000-0000-0000-000000000003',
    'Vitality Mix',
    'A diverse day blending omega-3 rich fish, whole grains, and lean proteins for overall vitality.',
    'general_health',
    2065, 148, 210, 68,
    ARRAY['high_protein', 'gluten_free']
);

INSERT INTO public.meal_plan_items (template_id, recipe_id, meal_type, servings, sort_order) VALUES
('40000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000006', 'breakfast', 1, 1),
('40000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000004', 'lunch', 1, 2),
('40000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000006', 'dinner', 1, 3),
('40000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000004', 'snack', 1, 4),
('40000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000005', 'snack', 1, 5),
('40000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000002', 'snack', 1, 6),
('40000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000002', 'snack', 1, 7);
