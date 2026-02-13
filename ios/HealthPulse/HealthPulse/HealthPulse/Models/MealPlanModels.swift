//
//  MealPlanModels.swift
//  HealthPulse
//
//  Models for recipes, meal plan templates, barcode scanning
//

import SwiftUI

// MARK: - Recipe Category

enum RecipeCategory: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack, dessert, shake

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        case .shake: return "Shake"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .dessert: return "birthday.cake.fill"
        case .shake: return "cup.and.saucer.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        case .dessert: return .pink
        case .shake: return .purple
        }
    }
}

// MARK: - Recipe Ingredient

struct RecipeIngredient: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let unit: String
}

// MARK: - Recipe

struct Recipe: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let description: String?
    let ingredients: [RecipeIngredient]?
    let instructions: [String]?
    let prepTimeMin: Int?
    let cookTimeMin: Int?
    let servings: Int?
    let caloriesPerServing: Double
    let proteinGPerServing: Double
    let carbsGPerServing: Double
    let fatGPerServing: Double
    let fiberGPerServing: Double
    let tags: [String]
    let goalTypes: [String]
    let imageUrl: String?
    let createdAt: Date?

    var recipeCategory: RecipeCategory? {
        RecipeCategory(rawValue: category)
    }

    var totalTimeMin: Int? {
        guard let prep = prepTimeMin else { return cookTimeMin }
        guard let cook = cookTimeMin else { return prep }
        return prep + cook
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, description, ingredients, instructions, servings, tags
        case prepTimeMin = "prep_time_min"
        case cookTimeMin = "cook_time_min"
        case caloriesPerServing = "calories_per_serving"
        case proteinGPerServing = "protein_g_per_serving"
        case carbsGPerServing = "carbs_g_per_serving"
        case fatGPerServing = "fat_g_per_serving"
        case fiberGPerServing = "fiber_g_per_serving"
        case goalTypes = "goal_types"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}

// MARK: - Meal Plan Item

struct MealPlanItem: Codable, Identifiable {
    let id: UUID
    let recipeId: UUID
    let recipe: Recipe?
    let mealType: String
    let servings: Double
    let sortOrder: Int
    let totalCalories: Double?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?

    var mealCategory: RecipeCategory? {
        RecipeCategory(rawValue: mealType)
    }

    enum CodingKeys: String, CodingKey {
        case id, recipe, servings
        case recipeId = "recipe_id"
        case mealType = "meal_type"
        case sortOrder = "sort_order"
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
    }
}

// MARK: - Meal Plan Template

struct MealPlanTemplate: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let goalType: String
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let tags: [String]
    let items: [MealPlanItem]?
    let itemCount: Int?

    var goalDisplayName: String {
        switch goalType {
        case "lose_weight": return "Weight Loss"
        case "build_muscle": return "Muscle Building"
        case "maintain": return "Maintenance"
        case "general_health": return "General Health"
        default: return goalType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var goalColor: Color {
        switch goalType {
        case "lose_weight": return .orange
        case "build_muscle": return .blue
        case "maintain": return .green
        case "general_health": return .purple
        default: return .gray
        }
    }

    var goalIcon: String {
        switch goalType {
        case "lose_weight": return "flame.fill"
        case "build_muscle": return "dumbbell.fill"
        case "maintain": return "equal.circle.fill"
        case "general_health": return "heart.fill"
        default: return "fork.knife"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, tags, items
        case goalType = "goal_type"
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case itemCount = "item_count"
    }
}

// MARK: - Quick Add Request

struct QuickAddRecipeRequest: Encodable {
    let recipeId: UUID
    let mealType: String
    let servings: Double
    let loggedAt: Date?

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case mealType = "meal_type"
        case servings
        case loggedAt = "logged_at"
    }
}

// MARK: - Barcode Product

struct BarcodeProduct: Codable {
    let barcode: String
    let name: String?
    let brand: String?
    let caloriesPer100g: Double
    let proteinGPer100g: Double
    let carbsGPer100g: Double
    let fatGPer100g: Double
    let fiberGPer100g: Double
    let servingSize: String?
    let imageUrl: String?
    let found: Bool

    var displayName: String {
        if let brand = brand, let name = name {
            return "\(brand) - \(name)"
        }
        return name ?? "Unknown Product"
    }

    enum CodingKeys: String, CodingKey {
        case barcode, name, brand, found
        case caloriesPer100g = "calories_per_100g"
        case proteinGPer100g = "protein_g_per_100g"
        case carbsGPer100g = "carbs_g_per_100g"
        case fatGPer100g = "fat_g_per_100g"
        case fiberGPer100g = "fiber_g_per_100g"
        case servingSize = "serving_size"
        case imageUrl = "image_url"
    }
}

// MARK: - Shopping List Item

struct ShoppingListItem: Codable, Identifiable {
    var id: String { "\(name)|\(unit)" }
    let name: String
    let totalAmount: Double
    let unit: String

    var displayAmount: String {
        if totalAmount == totalAmount.rounded() {
            return "\(Int(totalAmount))\(unit)"
        }
        return String(format: "%.1f%@", totalAmount, unit)
    }

    enum CodingKeys: String, CodingKey {
        case name, unit
        case totalAmount = "total_amount"
    }
}
