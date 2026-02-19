//
//  FoodScanModels.swift
//  HealthPulse
//
//  Models for AI food scanning and USDA nutrition lookup.
//

import Foundation

// MARK: - On-device CoreML Classification Result

struct FoodClassification: Identifiable {
    let id = UUID()
    let label: String           // e.g. "grilled_chicken"
    let confidence: Double      // 0.0-1.0
    let displayName: String     // e.g. "Grilled Chicken"
}

// MARK: - Cloud Scan Request

struct FoodScanRequest: Encodable {
    let imageBase64: String
    let classificationHints: [String]

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case classificationHints = "classification_hints"
    }
}

// MARK: - Scanned Food Item (from backend cloud API or USDA)

struct ScannedFoodItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var portionDescription: String
    var portionGrams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, confidence
        case portionDescription = "portion_description"
        case portionGrams = "portion_grams"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
    }

    /// Create a scaled copy with adjusted portion and macros.
    func scaled(by multiplier: Double) -> ScannedFoodItem {
        ScannedFoodItem(
            id: id,
            name: name,
            portionDescription: portionDescription,
            portionGrams: portionGrams * multiplier,
            calories: calories * multiplier,
            proteinG: proteinG * multiplier,
            carbsG: carbsG * multiplier,
            fatG: fatG * multiplier,
            fiberG: fiberG * multiplier,
            confidence: confidence
        )
    }
}

// MARK: - Cloud Scan Response

struct FoodScanResponse: Codable {
    let items: [ScannedFoodItem]
    let processingTimeMs: Int
    let provider: String

    enum CodingKeys: String, CodingKey {
        case items
        case processingTimeMs = "processing_time_ms"
        case provider
    }
}

// MARK: - USDA FoodData Central API Response Models

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]

    var id: Int { fdcId }

    /// Extract calories (nutrient ID 1008)
    var calories: Double {
        foodNutrients.first { $0.nutrientId == 1008 }?.value ?? 0
    }

    /// Extract protein in grams (nutrient ID 1003)
    var proteinG: Double {
        foodNutrients.first { $0.nutrientId == 1003 }?.value ?? 0
    }

    /// Extract carbs in grams (nutrient ID 1005)
    var carbsG: Double {
        foodNutrients.first { $0.nutrientId == 1005 }?.value ?? 0
    }

    /// Extract fat in grams (nutrient ID 1004)
    var fatG: Double {
        foodNutrients.first { $0.nutrientId == 1004 }?.value ?? 0
    }

    /// Extract fiber in grams (nutrient ID 1079)
    var fiberG: Double {
        foodNutrients.first { $0.nutrientId == 1079 }?.value ?? 0
    }

    /// Convert to ScannedFoodItem (per 100g serving)
    func toScannedFoodItem() -> ScannedFoodItem {
        ScannedFoodItem(
            id: UUID(),
            name: description.capitalized,
            portionDescription: "100g serving",
            portionGrams: 100,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            confidence: 1.0
        )
    }
}

struct USDANutrient: Codable {
    let nutrientId: Int
    let nutrientName: String
    let value: Double
    let unitName: String
}
