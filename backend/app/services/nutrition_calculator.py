"""Nutrition calculator service for BMR, TDEE, macro, and calorie cycling calculations.

Provides:
- BMR calculation using Mifflin-St Jeor (default) or Katch-McArdle (when body fat % known)
- TDEE calculation with activity multipliers
- Goal-based calorie and macro targets
- Calorie/macro cycling: training day vs rest day redistribution
- Goal timeline validation with safe rate boundaries
- Calorie floor enforcement
- Nutrition score calculation for wellness integration
"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class ActivityMultiplier(float, Enum):
    """Activity level multipliers for TDEE calculation."""
    SEDENTARY = 1.2      # Little or no exercise
    LIGHT = 1.375        # Exercise 1-3 days/week
    MODERATE = 1.55      # Exercise 3-5 days/week
    ACTIVE = 1.725       # Exercise 6-7 days/week
    VERY_ACTIVE = 1.9    # Very intense daily exercise


@dataclass
class MacroDistribution:
    """Macro distribution percentages."""
    protein_pct: float
    carbs_pct: float
    fat_pct: float


# Goal-based macro distributions (used as non-cycling defaults)
MACRO_DISTRIBUTIONS: dict[str, MacroDistribution] = {
    "lose_weight": MacroDistribution(protein_pct=0.40, carbs_pct=0.30, fat_pct=0.30),
    "build_muscle": MacroDistribution(protein_pct=0.30, carbs_pct=0.45, fat_pct=0.25),
    "maintain": MacroDistribution(protein_pct=0.25, carbs_pct=0.45, fat_pct=0.30),
    "general_health": MacroDistribution(protein_pct=0.20, carbs_pct=0.50, fat_pct=0.30),
}

# Calorie cycling macro distributions by day type
CYCLING_MACRO_DISTRIBUTIONS: dict[str, dict[str, MacroDistribution]] = {
    "lose_weight": {
        "training": MacroDistribution(protein_pct=0.35, carbs_pct=0.40, fat_pct=0.25),
        "rest": MacroDistribution(protein_pct=0.40, carbs_pct=0.25, fat_pct=0.35),
    },
    "build_muscle": {
        "training": MacroDistribution(protein_pct=0.30, carbs_pct=0.45, fat_pct=0.25),
        "rest": MacroDistribution(protein_pct=0.35, carbs_pct=0.30, fat_pct=0.35),
    },
    "maintain": {
        "training": MacroDistribution(protein_pct=0.25, carbs_pct=0.50, fat_pct=0.25),
        "rest": MacroDistribution(protein_pct=0.30, carbs_pct=0.35, fat_pct=0.35),
    },
    "general_health": {
        "training": MacroDistribution(protein_pct=0.25, carbs_pct=0.45, fat_pct=0.30),
        "rest": MacroDistribution(protein_pct=0.25, carbs_pct=0.40, fat_pct=0.35),
    },
}

# Calorie adjustments by goal
CALORIE_ADJUSTMENTS: dict[str, int] = {
    "lose_weight": -500,     # 500 cal deficit
    "build_muscle": 300,     # 300 cal surplus
    "maintain": 0,           # No adjustment
    "general_health": 0,     # No adjustment
}

# Calorie cycling: training day boost factor
TRAINING_DAY_BOOST = 1.10  # +10% on training days

# Protein floor: minimum g/kg body weight regardless of percentage calc
PROTEIN_FLOOR_G_PER_KG = 1.6

# Calorie floors
CALORIE_FLOOR_MALE = 1500
CALORIE_FLOOR_FEMALE = 1200

# Goal timeline constants
KCAL_PER_KG = 7700  # kcal energy per kg of body weight


@dataclass
class NutritionTargets:
    """Calculated nutrition targets."""
    bmr: float
    tdee: float
    calorie_target: float
    protein_g: float
    carbs_g: float
    fat_g: float
    protein_pct: float
    carbs_pct: float
    fat_pct: float
    bmr_formula: str = "mifflin_st_jeor"  # or "katch_mcardle"


@dataclass
class DailyTargets:
    """Cycling-aware daily targets for a specific date."""
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    is_training_day: bool
    protein_pct: float
    carbs_pct: float
    fat_pct: float


@dataclass
class GoalTimelineValidation:
    """Result of validating a goal timeline."""
    is_safe: bool
    weekly_rate_kg: float
    weekly_rate_pct: float
    daily_adjustment_kcal: float
    suggested_min_weeks: int  # minimum weeks for safe rate
    safety_level: str  # "green", "yellow", "orange", "red"
    message: str
    calorie_target: float  # after applying floor and adjustment
    calorie_floor_applied: bool


@dataclass
class NutritionScoreBreakdown:
    """Breakdown of nutrition score components."""
    overall_score: float
    calorie_adherence_score: float
    macro_balance_score: float
    consistency_score: float
    contributing_factors: dict


class NutritionCalculator:
    """Calculate nutrition targets and scores."""

    # Caloric values per gram of macronutrient
    CALORIES_PER_GRAM = {
        "protein": 4,
        "carbs": 4,
        "fat": 9,
    }

    def calculate_bmr(
        self,
        weight_kg: float,
        height_cm: float,
        age: int,
        gender: str,
        body_fat_pct: Optional[float] = None,
    ) -> tuple[float, str]:
        """Calculate Basal Metabolic Rate.

        Uses Katch-McArdle when body fat % is available (superior for
        lean/muscular or obese individuals). Falls back to Mifflin-St Jeor.

        Katch-McArdle: BMR = 370 + (21.6 × LBM_kg)
        Mifflin-St Jeor:
            Men:   BMR = (10 × weight) + (6.25 × height) - (5 × age) + 5
            Women: BMR = (10 × weight) + (6.25 × height) - (5 × age) - 161

        Args:
            weight_kg: Body weight in kilograms
            height_cm: Height in centimeters
            age: Age in years
            gender: 'male', 'female', or 'other'
            body_fat_pct: Optional body fat percentage (3-60)

        Returns:
            Tuple of (BMR in calories per day, formula name used)
        """
        # Use Katch-McArdle if body fat % is available and valid
        if body_fat_pct is not None and 3.0 <= body_fat_pct <= 60.0:
            body_fat_fraction = body_fat_pct / 100.0
            lean_body_mass = weight_kg * (1 - body_fat_fraction)
            bmr = 370 + (21.6 * lean_body_mass)
            return bmr, "katch_mcardle"

        # Fall back to Mifflin-St Jeor
        base_bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age)

        if gender.lower() == "male":
            return base_bmr + 5, "mifflin_st_jeor"
        else:
            return base_bmr - 161, "mifflin_st_jeor"

    def calculate_tdee(
        self,
        bmr: float,
        activity_level: str,
        activity_adjustment: float = 0,
    ) -> float:
        """Calculate Total Daily Energy Expenditure.

        TDEE = BMR × Activity Multiplier + Activity Adjustment

        Args:
            bmr: Basal Metabolic Rate
            activity_level: sedentary, light, moderate, active, very_active
            activity_adjustment: Extra calories from logged workouts/activity

        Returns:
            TDEE in calories per day
        """
        try:
            multiplier = ActivityMultiplier[activity_level.upper()].value
        except KeyError:
            multiplier = ActivityMultiplier.MODERATE.value

        base_tdee = bmr * multiplier
        return base_tdee + activity_adjustment

    def calculate_macro_grams(
        self,
        calorie_target: float,
        distribution: MacroDistribution,
    ) -> tuple[float, float, float]:
        """Calculate macro targets in grams from calorie target and distribution.

        Args:
            calorie_target: Daily calorie goal
            distribution: Macro percentage distribution

        Returns:
            Tuple of (protein_g, carbs_g, fat_g)
        """
        protein_calories = calorie_target * distribution.protein_pct
        carbs_calories = calorie_target * distribution.carbs_pct
        fat_calories = calorie_target * distribution.fat_pct

        protein_g = protein_calories / self.CALORIES_PER_GRAM["protein"]
        carbs_g = carbs_calories / self.CALORIES_PER_GRAM["carbs"]
        fat_g = fat_calories / self.CALORIES_PER_GRAM["fat"]

        return protein_g, carbs_g, fat_g

    def calculate_targets(
        self,
        weight_kg: float,
        height_cm: float,
        age: int,
        gender: str,
        activity_level: str,
        goal_type: str,
        activity_adjustment: float = 0,
        custom_calorie_target: Optional[float] = None,
        custom_protein_g: Optional[float] = None,
        custom_carbs_g: Optional[float] = None,
        custom_fat_g: Optional[float] = None,
        body_fat_pct: Optional[float] = None,
    ) -> NutritionTargets:
        """Calculate complete nutrition targets.

        Uses Katch-McArdle for BMR when body_fat_pct is provided,
        otherwise falls back to Mifflin-St Jeor.

        Args:
            weight_kg: Body weight in kilograms
            height_cm: Height in centimeters
            age: Age in years
            gender: 'male', 'female', or 'other'
            activity_level: Activity level string
            goal_type: Nutrition goal type
            activity_adjustment: Extra calories from logged activity
            custom_calorie_target: Override calculated calorie target
            custom_protein_g: Override calculated protein target
            custom_carbs_g: Override calculated carbs target
            custom_fat_g: Override calculated fat target
            body_fat_pct: Optional body fat percentage for Katch-McArdle

        Returns:
            NutritionTargets with all calculated values
        """
        # Calculate BMR (dual formula)
        bmr, bmr_formula = self.calculate_bmr(
            weight_kg, height_cm, age, gender, body_fat_pct
        )

        # Calculate TDEE
        tdee = self.calculate_tdee(bmr, activity_level, activity_adjustment)

        # Apply goal-based calorie adjustment
        if custom_calorie_target is not None:
            calorie_target = custom_calorie_target
        else:
            adjustment = CALORIE_ADJUSTMENTS.get(goal_type, 0)
            calorie_target = tdee + adjustment

        # Enforce calorie floor
        calorie_target = self._apply_calorie_floor(calorie_target, bmr, gender)

        # Get macro distribution for goal
        distribution = MACRO_DISTRIBUTIONS.get(
            goal_type,
            MACRO_DISTRIBUTIONS["general_health"]
        )

        # Calculate default macro targets
        default_protein, default_carbs, default_fat = self.calculate_macro_grams(
            calorie_target, distribution
        )

        # Enforce protein floor (1.6 g/kg body weight)
        min_protein = weight_kg * PROTEIN_FLOOR_G_PER_KG
        if default_protein < min_protein:
            default_protein = min_protein

        # Apply custom overrides if provided
        protein_g = custom_protein_g if custom_protein_g is not None else default_protein
        carbs_g = custom_carbs_g if custom_carbs_g is not None else default_carbs
        fat_g = custom_fat_g if custom_fat_g is not None else default_fat

        return NutritionTargets(
            bmr=round(bmr, 1),
            tdee=round(tdee, 1),
            calorie_target=round(calorie_target, 1),
            protein_g=round(protein_g, 1),
            carbs_g=round(carbs_g, 1),
            fat_g=round(fat_g, 1),
            protein_pct=distribution.protein_pct * 100,
            carbs_pct=distribution.carbs_pct * 100,
            fat_pct=distribution.fat_pct * 100,
            bmr_formula=bmr_formula,
        )

    def calculate_cycling_targets(
        self,
        daily_calorie_target: float,
        goal_type: str,
        training_days_per_week: int,
        is_training_day: bool,
        weight_kg: float,
    ) -> DailyTargets:
        """Calculate cycling-aware daily targets for training or rest day.

        Weekly total is preserved: training days get +10% kcal, rest days
        get the compensating reduction. Macros shift toward carbs on training
        days and toward protein/fat on rest days.

        Args:
            daily_calorie_target: Base TDEE-adjusted daily target
            goal_type: Nutrition goal type
            training_days_per_week: Number of training days (1-7)
            is_training_day: Whether today is a training day
            weight_kg: Body weight for protein floor calculation

        Returns:
            DailyTargets with cycling-adjusted calories and macros
        """
        t = min(max(training_days_per_week, 1), 7)
        r = 7 - t

        if is_training_day:
            day_kcal = daily_calorie_target * TRAINING_DAY_BOOST
        else:
            if r > 0:
                day_kcal = daily_calorie_target * (7 - TRAINING_DAY_BOOST * t) / r
            else:
                # All 7 days are training days — no cycling possible
                day_kcal = daily_calorie_target

        # Get cycling macro distribution
        day_type = "training" if is_training_day else "rest"
        cycling_dists = CYCLING_MACRO_DISTRIBUTIONS.get(goal_type)
        if cycling_dists:
            dist = cycling_dists[day_type]
        else:
            dist = MACRO_DISTRIBUTIONS.get(goal_type, MACRO_DISTRIBUTIONS["general_health"])

        protein_g, carbs_g, fat_g = self.calculate_macro_grams(day_kcal, dist)

        # Enforce protein floor
        min_protein = weight_kg * PROTEIN_FLOOR_G_PER_KG
        if protein_g < min_protein:
            protein_g = min_protein

        return DailyTargets(
            calories=round(day_kcal, 1),
            protein_g=round(protein_g, 1),
            carbs_g=round(carbs_g, 1),
            fat_g=round(fat_g, 1),
            is_training_day=is_training_day,
            protein_pct=dist.protein_pct * 100,
            carbs_pct=dist.carbs_pct * 100,
            fat_pct=dist.fat_pct * 100,
        )

    def validate_goal_timeline(
        self,
        current_weight_kg: float,
        target_weight_kg: float,
        timeframe_days: int,
        gender: str,
        bmr: float,
        tdee: float,
    ) -> GoalTimelineValidation:
        """Validate a weight goal timeline against safe rate boundaries.

        Safe rates (percentage of body weight per week):
        - Loss: max 1.0% BW/week (conservative 0.5%)
        - Gain: max 0.5% BW/week (conservative 0.25%)

        Args:
            current_weight_kg: Current body weight
            target_weight_kg: Target body weight
            timeframe_days: Desired timeframe in days
            gender: For calorie floor determination
            bmr: Calculated BMR
            tdee: Calculated TDEE

        Returns:
            GoalTimelineValidation with safety assessment
        """
        delta_kg = abs(current_weight_kg - target_weight_kg)
        direction = "loss" if target_weight_kg < current_weight_kg else "gain"
        weeks_requested = max(timeframe_days / 7, 0.5)  # prevent division by zero

        weekly_rate_kg = delta_kg / weeks_requested
        weekly_rate_pct = (weekly_rate_kg / current_weight_kg) * 100

        # Max safe rates
        max_rate_pct = 1.0 if direction == "loss" else 0.5

        # Calculate daily calorie adjustment
        daily_adjustment = (weekly_rate_kg * KCAL_PER_KG) / 7
        if direction == "loss":
            daily_adjustment = -daily_adjustment

        calorie_target = tdee + daily_adjustment

        # Apply calorie floor
        floor = self._get_calorie_floor(bmr, gender)
        calorie_floor_applied = calorie_target < floor
        if calorie_floor_applied:
            calorie_target = floor
            # Recalculate achievable rate from capped target
            actual_daily_deficit = abs(tdee - calorie_target)
            weekly_rate_kg = (actual_daily_deficit * 7) / KCAL_PER_KG
            weekly_rate_pct = (weekly_rate_kg / current_weight_kg) * 100

        # Determine safety level
        if weekly_rate_pct <= 0.5:
            safety_level = "green"
            message = "Conservative and sustainable pace."
        elif weekly_rate_pct <= 0.75:
            safety_level = "yellow"
            message = "Moderate pace — sustainable for most people."
        elif weekly_rate_pct <= max_rate_pct:
            safety_level = "orange"
            message = f"Aggressive but within safe limits for {direction}."
        else:
            safety_level = "red"
            message = (
                f"{'Losing' if direction == 'loss' else 'Gaining'} "
                f"{delta_kg:.1f} kg in {int(weeks_requested)} weeks requires "
                f"{weekly_rate_pct:.1f}% body weight per week, which exceeds "
                f"safe guidelines ({max_rate_pct}% max)."
            )

        # Calculate minimum safe weeks (at 0.75% BW/week — moderate pace)
        safe_weekly_kg = current_weight_kg * 0.0075
        suggested_min_weeks = max(1, int(delta_kg / safe_weekly_kg) + 1) if safe_weekly_kg > 0 else 12

        return GoalTimelineValidation(
            is_safe=weekly_rate_pct <= max_rate_pct,
            weekly_rate_kg=round(weekly_rate_kg, 2),
            weekly_rate_pct=round(weekly_rate_pct, 2),
            daily_adjustment_kcal=round(daily_adjustment, 1),
            suggested_min_weeks=suggested_min_weeks,
            safety_level=safety_level,
            message=message,
            calorie_target=round(calorie_target, 1),
            calorie_floor_applied=calorie_floor_applied,
        )

    def _apply_calorie_floor(self, calorie_target: float, bmr: float, gender: str) -> float:
        """Enforce minimum calorie floor."""
        floor = self._get_calorie_floor(bmr, gender)
        return max(calorie_target, floor)

    def _get_calorie_floor(self, bmr: float, gender: str) -> float:
        """Get the absolute calorie floor for a given gender and BMR."""
        if gender.lower() == "male":
            return max(CALORIE_FLOOR_MALE, bmr)
        else:
            return max(CALORIE_FLOOR_FEMALE, bmr)

    def calculate_nutrition_score(
        self,
        calories_consumed: float,
        calorie_target: float,
        protein_consumed: float,
        protein_target: float,
        carbs_consumed: float,
        carbs_target: float,
        fat_consumed: float,
        fat_target: float,
        days_logged_this_week: int = 7,
    ) -> NutritionScoreBreakdown:
        """Calculate nutrition score (0-100) for wellness integration.

        Components (weighted):
        - Calorie adherence (40%): How close to target calories
        - Macro balance (40%): How well macros match targets
        - Consistency (20%): Regular logging habits

        Args:
            calories_consumed: Total calories consumed
            calorie_target: Target calories
            protein_consumed: Protein consumed in grams
            protein_target: Target protein in grams
            carbs_consumed: Carbs consumed in grams
            carbs_target: Target carbs in grams
            fat_consumed: Fat consumed in grams
            fat_target: Target fat in grams
            days_logged_this_week: Number of days with logged entries this week

        Returns:
            NutritionScoreBreakdown with overall and component scores
        """
        factors: dict = {}

        # Calorie adherence score (0-100)
        calorie_score = self._calculate_adherence_score(
            calories_consumed, calorie_target, "calories"
        )
        factors["calories"] = {
            "consumed": round(calories_consumed, 1),
            "target": round(calorie_target, 1),
            "ratio": round(calories_consumed / calorie_target, 2) if calorie_target > 0 else 0,
            "score": round(calorie_score, 1),
            "impact": "positive" if calorie_score >= 70 else "negative"
        }

        # Macro balance scores
        macro_scores = []

        for name, consumed, target in [
            ("protein", protein_consumed, protein_target),
            ("carbs", carbs_consumed, carbs_target),
            ("fat", fat_consumed, fat_target),
        ]:
            score = self._calculate_adherence_score(consumed, target, name)
            macro_scores.append(score)

            factors[name] = {
                "consumed": round(consumed, 1),
                "target": round(target, 1),
                "ratio": round(consumed / target, 2) if target > 0 else 0,
                "score": round(score, 1),
                "impact": "positive" if score >= 70 else "negative"
            }

        macro_balance_score = sum(macro_scores) / len(macro_scores) if macro_scores else 50.0

        # Consistency score (based on days logged)
        consistency_score = min(100, (days_logged_this_week / 7) * 100)
        factors["consistency"] = {
            "days_logged": days_logged_this_week,
            "score": round(consistency_score, 1),
            "impact": "positive" if consistency_score >= 70 else "negative"
        }

        # Weighted overall score
        overall_score = (
            calorie_score * 0.40 +
            macro_balance_score * 0.40 +
            consistency_score * 0.20
        )

        return NutritionScoreBreakdown(
            overall_score=round(overall_score, 1),
            calorie_adherence_score=round(calorie_score, 1),
            macro_balance_score=round(macro_balance_score, 1),
            consistency_score=round(consistency_score, 1),
            contributing_factors=factors,
        )

    def _calculate_adherence_score(
        self,
        consumed: float,
        target: float,
        name: str,
    ) -> float:
        """Calculate adherence score for a single metric.

        Scoring:
        - Within 10% of target: 90-100 points
        - Within 20% of target: 70-90 points
        - Beyond 20%: Decreasing score

        Args:
            consumed: Amount consumed
            target: Target amount
            name: Metric name for logging

        Returns:
            Score from 0-100
        """
        if target <= 0:
            return 50.0

        ratio = consumed / target
        deviation = abs(1 - ratio)

        if deviation <= 0.10:  # Within 10%
            return 100 - (deviation * 100)
        elif deviation <= 0.20:  # Within 20%
            return 80 - ((deviation - 0.10) * 100)
        elif deviation <= 0.50:  # Within 50%
            return 60 - ((deviation - 0.20) * 100)
        else:
            return max(0, 30 - ((deviation - 0.50) * 60))

    def get_activity_calories_from_workouts(
        self,
        workouts: list[dict],
    ) -> float:
        """Calculate extra calories burned from logged workouts.

        This adjustment is added to TDEE when adjust_for_activity is enabled.

        Args:
            workouts: List of workout dicts with 'calories_burned' field

        Returns:
            Total calories burned from workouts
        """
        total = 0.0
        for workout in workouts:
            calories = workout.get("calories_burned")
            if calories:
                total += float(calories)
        return total


# Singleton instance
_calculator: NutritionCalculator | None = None


def get_nutrition_calculator() -> NutritionCalculator:
    """Get or create the nutrition calculator instance."""
    global _calculator
    if _calculator is None:
        _calculator = NutritionCalculator()
    return _calculator
