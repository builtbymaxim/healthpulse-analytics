//
//  NutritionModels.swift
//  HealthPulse
//
//  Nutrition tracking models for calorie and macro management
//

import Foundation
import SwiftUI

// MARK: - Enums

enum Gender: String, Codable, CaseIterable {
    case male
    case female
    case other

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive = "very_active"

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little to no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum NutritionGoalType: String, Codable, CaseIterable {
    case loseWeight = "lose_weight"
    case buildMuscle = "build_muscle"
    case maintain
    case health = "general_health"

    var displayName: String {
        switch self {
        case .loseWeight: return "Lose Weight"
        case .buildMuscle: return "Build Muscle"
        case .maintain: return "Maintain Weight"
        case .health: return "General Health"
        }
    }

    var description: String {
        switch self {
        case .loseWeight: return "Calorie deficit to lose ~0.5kg/week safely"
        case .buildMuscle: return "Calorie surplus + high protein for gains"
        case .maintain: return "Keep your current weight & body composition"
        case .health: return "No strict tracking, focus on balanced eating"
        }
    }

    var detailedDescription: String {
        switch self {
        case .loseWeight:
            return "We'll set a 500 kcal daily deficit. Track your food to stay on target. Expect to lose about 0.5kg per week."
        case .buildMuscle:
            return "We'll add 300 kcal surplus with high protein (2g/kg). Combine with strength training for best results."
        case .maintain:
            return "Perfect if you're happy with your weight. We'll calculate your maintenance calories to stay stable."
        case .health:
            return "No calorie counting pressure. We'll suggest balanced meals without strict tracking."
        }
    }

    /// Suggests a target weight based on current weight and goal
    func suggestedTargetWeight(currentWeight: Double) -> Double {
        switch self {
        case .loseWeight:
            // Suggest losing 5-10% of body weight (use 8% as default)
            return round(currentWeight * 0.92 * 10) / 10
        case .buildMuscle:
            // Suggest gaining 3-5kg of lean mass
            return round((currentWeight + 4) * 10) / 10
        case .maintain, .health:
            return currentWeight
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: return "arrow.down.circle.fill"
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .maintain: return "equal.circle.fill"
        case .health: return "heart.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .loseWeight: return .blue
        case .buildMuscle: return .orange
        case .maintain: return .green
        case .health: return .pink
        }
    }
}

// Typealias for backward compatibility
typealias FitnessGoal = NutritionGoalType

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
}

// MARK: - Physical Profile

struct PhysicalProfile: Codable {
    var age: Int?
    var heightCm: Double?
    var gender: String?
    var activityLevel: String?
    var latestWeightKg: Double?
    var profileComplete: Bool

    enum CodingKeys: String, CodingKey {
        case age
        case heightCm = "height_cm"
        case gender
        case activityLevel = "activity_level"
        case latestWeightKg = "latest_weight_kg"
        case profileComplete = "profile_complete"
    }

    var genderEnum: Gender? {
        guard let g = gender else { return nil }
        return Gender(rawValue: g)
    }

    var activityLevelEnum: ActivityLevel? {
        guard let al = activityLevel else { return nil }
        return ActivityLevel(rawValue: al)
    }
}

struct PhysicalProfileUpdate: Encodable {
    let age: Int
    let heightCm: Double
    let gender: String
    let activityLevel: String

    enum CodingKeys: String, CodingKey {
        case age
        case heightCm = "height_cm"
        case gender
        case activityLevel = "activity_level"
    }
}

// MARK: - Nutrition Goal

struct NutritionGoal: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let goalType: String
    let bmr: Double?
    let tdee: Double?
    let calorieTarget: Double?
    let proteinTargetG: Double?
    let carbsTargetG: Double?
    let fatTargetG: Double?
    let customCalorieTarget: Double?
    let customProteinTargetG: Double?
    let customCarbsTargetG: Double?
    let customFatTargetG: Double?
    let adjustForActivity: Bool
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case goalType = "goal_type"
        case bmr, tdee
        case calorieTarget = "calorie_target"
        case proteinTargetG = "protein_target_g"
        case carbsTargetG = "carbs_target_g"
        case fatTargetG = "fat_target_g"
        case customCalorieTarget = "custom_calorie_target"
        case customProteinTargetG = "custom_protein_target_g"
        case customCarbsTargetG = "custom_carbs_target_g"
        case customFatTargetG = "custom_fat_target_g"
        case adjustForActivity = "adjust_for_activity"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var goalTypeEnum: NutritionGoalType? {
        NutritionGoalType(rawValue: goalType)
    }

    var effectiveCalorieTarget: Double {
        customCalorieTarget ?? calorieTarget ?? 2000
    }

    var effectiveProteinTarget: Double {
        customProteinTargetG ?? proteinTargetG ?? 150
    }

    var effectiveCarbsTarget: Double {
        customCarbsTargetG ?? carbsTargetG ?? 250
    }

    var effectiveFatTarget: Double {
        customFatTargetG ?? fatTargetG ?? 65
    }
}

struct NutritionGoalCreate: Encodable {
    let goalType: String
    let customCalorieTarget: Double?
    let customProteinTargetG: Double?
    let customCarbsTargetG: Double?
    let customFatTargetG: Double?
    let adjustForActivity: Bool

    enum CodingKeys: String, CodingKey {
        case goalType = "goal_type"
        case customCalorieTarget = "custom_calorie_target"
        case customProteinTargetG = "custom_protein_target_g"
        case customCarbsTargetG = "custom_carbs_target_g"
        case customFatTargetG = "custom_fat_target_g"
        case adjustForActivity = "adjust_for_activity"
    }

    init(goalType: NutritionGoalType, customCalorieTarget: Double? = nil,
         customProteinTargetG: Double? = nil, customCarbsTargetG: Double? = nil,
         customFatTargetG: Double? = nil, adjustForActivity: Bool = true) {
        self.goalType = goalType.rawValue
        self.customCalorieTarget = customCalorieTarget
        self.customProteinTargetG = customProteinTargetG
        self.customCarbsTargetG = customCarbsTargetG
        self.customFatTargetG = customFatTargetG
        self.adjustForActivity = adjustForActivity
    }
}

// MARK: - Food Entry

struct FoodEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let mealType: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let servingSize: Double
    let servingUnit: String
    let loggedAt: Date
    let notes: String?
    let source: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case mealType = "meal_type"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case loggedAt = "logged_at"
        case notes
        case source
        case createdAt = "created_at"
    }

    var mealTypeEnum: MealType? {
        guard let mt = mealType else { return nil }
        return MealType(rawValue: mt)
    }
}

struct FoodEntryCreate: Encodable {
    let name: String
    let mealType: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let servingSize: Double
    let servingUnit: String
    let loggedAt: Date?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name
        case mealType = "meal_type"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case loggedAt = "logged_at"
        case notes
    }

    init(name: String, mealType: MealType? = nil, calories: Double,
         proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0,
         fiberG: Double = 0, servingSize: Double = 1, servingUnit: String = "serving",
         loggedAt: Date? = nil, notes: String? = nil) {
        self.name = name
        self.mealType = mealType?.rawValue
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.loggedAt = loggedAt
        self.notes = notes
    }
}

// MARK: - Daily Summary

struct DailyNutritionSummary: Codable {
    let date: String
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let calorieTarget: Double
    let proteinTargetG: Double
    let carbsTargetG: Double
    let fatTargetG: Double
    let calorieProgressPct: Double
    let proteinProgressPct: Double
    let carbsProgressPct: Double
    let fatProgressPct: Double
    let caloriesRemaining: Double
    let proteinRemainingG: Double
    let carbsRemainingG: Double
    let fatRemainingG: Double
    let nutritionScore: Double
    let scoreBreakdown: ScoreBreakdown?
    let entries: [FoodEntry]

    enum CodingKeys: String, CodingKey {
        case date
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case calorieTarget = "calorie_target"
        case proteinTargetG = "protein_target_g"
        case carbsTargetG = "carbs_target_g"
        case fatTargetG = "fat_target_g"
        case calorieProgressPct = "calorie_progress_pct"
        case proteinProgressPct = "protein_progress_pct"
        case carbsProgressPct = "carbs_progress_pct"
        case fatProgressPct = "fat_progress_pct"
        case caloriesRemaining = "calories_remaining"
        case proteinRemainingG = "protein_remaining_g"
        case carbsRemainingG = "carbs_remaining_g"
        case fatRemainingG = "fat_remaining_g"
        case nutritionScore = "nutrition_score"
        case scoreBreakdown = "score_breakdown"
        case entries
    }
}

struct ScoreBreakdown: Codable {
    let calorieAdherence: Double
    let macroBalance: Double
    let consistency: Double

    enum CodingKeys: String, CodingKey {
        case calorieAdherence = "calorie_adherence"
        case macroBalance = "macro_balance"
        case consistency
    }
}

// MARK: - Calorie Preview

struct CalorieTargetsPreview: Codable {
    let bmr: Double
    let tdee: Double
    let calorieTarget: Double
    let macros: MacroTargets
    let goalType: String
    let usingCustomValues: Bool

    enum CodingKeys: String, CodingKey {
        case bmr, tdee
        case calorieTarget = "calorie_target"
        case macros
        case goalType = "goal_type"
        case usingCustomValues = "using_custom_values"
    }
}

struct MacroTargets: Codable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let proteinPct: Double
    let carbsPct: Double
    let fatPct: Double

    enum CodingKeys: String, CodingKey {
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case proteinPct = "protein_pct"
        case carbsPct = "carbs_pct"
        case fatPct = "fat_pct"
    }
}
