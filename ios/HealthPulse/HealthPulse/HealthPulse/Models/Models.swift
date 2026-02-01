//
//  Models.swift
//  HealthPulse
//
//  Data models for the app
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    var displayName: String?
    var avatarUrl: String?
    var settings: UserSettings?
    var age: Int?
    var heightCm: Double?
    var gender: String?
    var activityLevel: String?
    var fitnessGoal: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case settings
        case age
        case heightCm = "height_cm"
        case gender
        case activityLevel = "activity_level"
        case fitnessGoal = "fitness_goal"
        case createdAt = "created_at"
    }

    /// Check if user has completed onboarding by verifying required profile fields
    var isProfileComplete: Bool {
        return age != nil && heightCm != nil && gender != nil
    }
}

struct UserSettings: Codable {
    var hrvBaseline: Double?
    var rhrBaseline: Double?
    var targetSleepHours: Double?
    var dailyStepGoal: Int?
    var useMetricUnits: Bool

    enum CodingKeys: String, CodingKey {
        case hrvBaseline = "hrv_baseline"
        case rhrBaseline = "rhr_baseline"
        case targetSleepHours = "target_sleep_hours"
        case dailyStepGoal = "daily_step_goal"
        case useMetricUnits = "use_metric_units"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hrvBaseline = try container.decodeIfPresent(Double.self, forKey: .hrvBaseline)
        rhrBaseline = try container.decodeIfPresent(Double.self, forKey: .rhrBaseline)
        targetSleepHours = try container.decodeIfPresent(Double.self, forKey: .targetSleepHours)
        dailyStepGoal = try container.decodeIfPresent(Int.self, forKey: .dailyStepGoal)
        useMetricUnits = try container.decodeIfPresent(Bool.self, forKey: .useMetricUnits) ?? true
    }
}

// MARK: - Health Metrics

struct HealthMetric: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let metricType: MetricType
    let value: Double
    var unit: String?
    var source: MetricSource
    var metadata: [String: String]?
    let recordedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case metricType = "metric_type"
        case value, unit, source, metadata
        case recordedAt = "recorded_at"
        case createdAt = "created_at"
    }
}

enum MetricType: String, Codable, CaseIterable {
    case steps
    case activeCalories = "active_calories"
    case restingHeartRate = "resting_heart_rate"
    case hrv
    case sleep
    case weight
    case bodyFat = "body_fat"
    case stress
    case mood
    case energy
    case soreness
    case water
    case caffeine
}

enum MetricSource: String, Codable {
    case manual
    case appleHealth = "apple_health"
    case garmin
    case fitbit
    case oura
    case whoop
}

// MARK: - Workouts

struct Workout: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let workoutType: WorkoutType
    let startedAt: Date
    var endedAt: Date?
    var durationMinutes: Int?
    var intensity: Intensity
    var caloriesBurned: Double?
    var averageHeartRate: Double?
    var trainingLoad: Double?
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutType = "workout_type"
        case startedAt = "start_time"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case intensity
        case caloriesBurned = "calories_burned"
        case averageHeartRate = "avg_heart_rate"
        case trainingLoad = "training_load"
        case notes
        case createdAt = "created_at"
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case running, cycling, swimming, walking, hiking
    case strength, hiit, yoga, pilates, crossfit
    case rowing, elliptical, stairClimber = "stair_climber"
    case weightTraining = "weight_training"
    case sports, other

    var displayName: String {
        switch self {
        case .stairClimber: return "Stair Climber"
        case .weightTraining: return "Weight Training"
        case .hiit: return "HIIT"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .strength: return "dumbbell.fill"
        case .weightTraining: return "dumbbell.fill"
        case .hiit: return "flame.fill"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .crossfit: return "figure.cross.training"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairClimber: return "figure.stair.stepper"
        case .sports: return "sportscourt.fill"
        case .other: return "figure.mixed.cardio"
        }
    }
}

enum Intensity: String, Codable, CaseIterable {
    case light, moderate, hard

    // Backend also supports very_hard but keeping it simple for UI

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        }
    }

    var color: String {
        switch self {
        case .light: return "green"
        case .moderate: return "orange"
        case .hard: return "red"
        }
    }
}

// MARK: - Predictions

struct RecoveryPrediction: Codable {
    let score: Double
    let confidence: Double
    let status: RecoveryStatus
    let contributingFactors: [String: FactorDetail]
    let recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case score, confidence, status
        case contributingFactors = "contributing_factors"
        case recommendations
    }
}

struct FactorDetail: Codable {
    let value: Double
    let score: Double
    let impact: String
}

enum RecoveryStatus: String, Codable {
    case recovered, moderate, fatigued

    var color: String {
        switch self {
        case .recovered: return "green"
        case .moderate: return "orange"
        case .fatigued: return "red"
        }
    }
}

struct ReadinessPrediction: Codable {
    let score: Double
    let confidence: Double
    let recommendedIntensity: String
    let factors: [String: FactorDetail]
    let suggestedWorkoutTypes: [String]

    enum CodingKeys: String, CodingKey {
        case score, confidence
        case recommendedIntensity = "recommended_intensity"
        case factors
        case suggestedWorkoutTypes = "suggested_workout_types"
    }
}

struct WellnessScore: Codable {
    let date: String
    let overallScore: Double
    let components: [String: Double]
    let trend: String
    let comparisonToBaseline: Double

    enum CodingKeys: String, CodingKey {
        case date
        case overallScore = "overall_score"
        case components, trend
        case comparisonToBaseline = "comparison_to_baseline"
    }
}

// MARK: - Insights

struct Insight: Codable, Identifiable {
    let id: UUID
    let category: InsightCategory
    let title: String
    let description: String
    let data: [String: String]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, category, title, description, data
        case createdAt = "created_at"
    }
}

enum InsightCategory: String, Codable {
    case correlation, anomaly, trend, recommendation, achievement

    var icon: String {
        switch self {
        case .correlation: return "link"
        case .anomaly: return "exclamationmark.triangle.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .recommendation: return "lightbulb.fill"
        case .achievement: return "trophy.fill"
        }
    }

    var color: String {
        switch self {
        case .correlation: return "blue"
        case .anomaly: return "red"
        case .trend: return "purple"
        case .recommendation: return "green"
        case .achievement: return "yellow"
        }
    }
}

struct Correlation: Codable {
    let factorA: String
    let factorB: String
    let correlation: Double
    let insight: String
    let dataPoints: Int
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case factorA = "factor_a"
        case factorB = "factor_b"
        case correlation, insight
        case dataPoints = "data_points"
        case confidence
    }
}
