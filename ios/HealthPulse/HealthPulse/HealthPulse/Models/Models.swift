//
//  Models.swift
//  HealthPulse
//
//  Data models for the app
//

import Foundation
import SwiftUI

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
    var socialOptIn: Bool
    // Dietary profile (Phase 8C)
    var dietaryPattern: String?
    var allergies: [String]?
    var mealsPerDay: Int?
    // Experience & motivation
    var experienceLevel: String?
    var motivation: String?
    var bodyFatPct: Double?

    enum CodingKeys: String, CodingKey {
        case hrvBaseline = "hrv_baseline"
        case rhrBaseline = "rhr_baseline"
        case targetSleepHours = "target_sleep_hours"
        case dailyStepGoal = "daily_step_goal"
        case useMetricUnits = "use_metric_units"
        case socialOptIn = "social_opt_in"
        case dietaryPattern = "dietary_pattern"
        case allergies
        case mealsPerDay = "meals_per_day"
        case experienceLevel = "experience_level"
        case motivation
        case bodyFatPct = "body_fat_pct"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hrvBaseline = try container.decodeIfPresent(Double.self, forKey: .hrvBaseline)
        rhrBaseline = try container.decodeIfPresent(Double.self, forKey: .rhrBaseline)
        targetSleepHours = try container.decodeIfPresent(Double.self, forKey: .targetSleepHours)
        dailyStepGoal = try container.decodeIfPresent(Int.self, forKey: .dailyStepGoal)
        useMetricUnits = try container.decodeIfPresent(Bool.self, forKey: .useMetricUnits) ?? true
        socialOptIn = try container.decodeIfPresent(Bool.self, forKey: .socialOptIn) ?? false
        dietaryPattern = try container.decodeIfPresent(String.self, forKey: .dietaryPattern)
        allergies = try container.decodeIfPresent([String].self, forKey: .allergies)
        mealsPerDay = try container.decodeIfPresent(Int.self, forKey: .mealsPerDay)
        experienceLevel = try container.decodeIfPresent(String.self, forKey: .experienceLevel)
        motivation = try container.decodeIfPresent(String.self, forKey: .motivation)
        bodyFatPct = try container.decodeIfPresent(Double.self, forKey: .bodyFatPct)
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
    case energy = "energy_level"
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

struct Workout: Codable, Identifiable, Hashable {
    static func == (lhs: Workout, rhs: Workout) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    let userId: UUID
    let workoutType: WorkoutType
    let startedAt: Date
    var endedAt: Date?
    var durationMinutes: Int?
    var intensity: Intensity?
    var caloriesBurned: Double?
    var averageHeartRate: Double?
    var trainingLoad: Double?
    var notes: String?
    let createdAt: Date
    // Training plan fields
    var planId: UUID?
    var plannedWorkoutName: String?
    var exercises: [ExerciseLog]?
    var overallRating: Int?

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
        case planId = "plan_id"
        case plannedWorkoutName = "planned_workout_name"
        case exercises
        case overallRating = "overall_rating"
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

    // Color for workout type
    var color: Color {
        switch self {
        case .strength, .weightTraining: return .green
        case .running, .hiking, .walking: return .orange
        case .cycling: return .blue
        case .swimming: return .cyan
        case .yoga, .pilates: return .purple
        case .hiit, .crossfit: return .red
        default: return .gray
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

// MARK: - Training Plans

struct TodayWorkoutResponse: Codable {
    let hasPlan: Bool
    let isRestDay: Bool
    let isCompleted: Bool?
    let workoutName: String?
    let workoutFocus: String?
    let exercises: [PlannedExercise]?
    let estimatedMinutes: Int?
    let dayOfWeek: Int
    let planName: String?
    let planId: UUID?

    enum CodingKeys: String, CodingKey {
        case hasPlan = "has_plan"
        case isRestDay = "is_rest_day"
        case isCompleted = "is_completed"
        case workoutName = "workout_name"
        case workoutFocus = "workout_focus"
        case exercises
        case estimatedMinutes = "estimated_minutes"
        case dayOfWeek = "day_of_week"
        case planName = "plan_name"
        case planId = "plan_id"
    }
}

struct UnifiedWorkoutEntry: Codable, Identifiable {
    let id: UUID
    let source: String // "freeform" or "plan"
    let workoutType: String
    let startTime: Date
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let notes: String?
    let planId: UUID?
    let plannedWorkoutName: String?
    let overallRating: Int?
    let intensity: String?

    enum CodingKeys: String, CodingKey {
        case id, source, notes, intensity
        case workoutType = "workout_type"
        case startTime = "start_time"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case planId = "plan_id"
        case plannedWorkoutName = "planned_workout_name"
        case overallRating = "overall_rating"
    }

    var displayName: String {
        plannedWorkoutName ?? workoutType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var isPlanWorkout: Bool { source == "plan" }
}

struct PlannedExercise: Codable, Identifiable {
    var id: String { name }
    let name: String
    let sets: Int?
    let reps: String?
    let notes: String?
    let isKeyLift: Bool?
    let restSeconds: Int?
}

struct TrainingPlanSummary: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let daysPerWeek: Int
    let schedule: [String: String]
    let isActive: Bool
    let workouts: [TemplateWorkout]?
    let customizations: [String: [String: String]]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, workouts, customizations
        case daysPerWeek = "days_per_week"
        case schedule
        case isActive = "is_active"
    }
}

struct PlanTemplate: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let daysPerWeek: Int
    let goalType: String
    let subGoals: [String]?
    let modality: String
    let equipmentRequired: [String]?
    let difficulty: String
    let workouts: [TemplateWorkout]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case daysPerWeek = "days_per_week"
        case goalType = "goal_type"
        case subGoals = "sub_goals"
        case modality
        case equipmentRequired = "equipment_required"
        case difficulty, workouts
    }
}

struct TemplateWorkout: Codable {
    let day: Int
    let name: String
    let focus: String?
    let estimatedMinutes: Int?
    let exercises: [PlannedExercise]?
}

// MARK: - Training Plan Requests/Responses

struct ActivatePlanRequest: Codable {
    let templateId: UUID
    let schedule: [String: String]

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case schedule
    }
}

struct ActivatePlanResponse: Codable {
    let success: Bool
    let planId: UUID

    enum CodingKeys: String, CodingKey {
        case success
        case planId = "plan_id"
    }
}

struct UpdatePlanRequest: Codable {
    let name: String?
    let schedule: [String: String]?
    let customizations: [String: [String: String]]?
}

struct UpdatePlanResponse: Codable {
    let success: Bool
}

struct WorkoutSessionRequest: Codable {
    let planId: UUID?
    let plannedWorkoutName: String?
    let startedAt: Date
    let completedAt: Date?
    let durationMinutes: Int?
    let exercises: [ExerciseLog]
    let overallRating: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case plannedWorkoutName = "planned_workout_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationMinutes = "duration_minutes"
        case exercises
        case overallRating = "overall_rating"
        case notes
    }
}

struct ExerciseLog: Codable, Identifiable {
    var id: String { name }
    let name: String
    let isKeyLift: Bool
    var sets: [SetLog]
    var isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isKeyLift = "is_key_lift"
        case sets
        case isCompleted = "is_completed"
    }
}

struct SetLog: Codable, Identifiable {
    let id: UUID
    var weight: Double
    var reps: Int
    var rpe: Int?
    var restTaken: Int?
    var isPR: Bool
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe
        case restTaken = "rest_taken"
        case isPR = "is_pr"
        case completedAt = "completed_at"
    }

    init(id: UUID = UUID(), weight: Double, reps: Int, rpe: Int? = nil, restTaken: Int? = nil, isPR: Bool = false, completedAt: Date = Date()) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.restTaken = restTaken
        self.isPR = isPR
        self.completedAt = completedAt
    }
}

struct WorkoutSessionResponse: Codable {
    let success: Bool
    let sessionId: UUID
    let prsAchieved: [PRInfo]

    enum CodingKeys: String, CodingKey {
        case success
        case sessionId = "session_id"
        case prsAchieved = "prs_achieved"
    }
}

struct PRInfo: Codable, Identifiable {
    var id: String { "\(exerciseName)-\(recordType)" }
    let exerciseName: String
    let recordType: String
    let value: Double
    let previousValue: Double?

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case recordType = "record_type"
        case value
        case previousValue = "previous_value"
    }
}

struct WorkoutSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID?
    let plannedWorkoutName: String?
    let startedAt: Date
    let completedAt: Date?
    let durationMinutes: Int?
    let exercises: [ExerciseLog]?
    let overallRating: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case plannedWorkoutName = "planned_workout_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationMinutes = "duration_minutes"
        case exercises
        case overallRating = "overall_rating"
        case notes
    }
}

struct ExerciseProgressResponse: Codable {
    let exerciseName: String
    let progress: [ProgressPoint]

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case progress
    }
}

struct ProgressPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let bestWeight: Double
    let bestReps: Int
    let totalVolume: Double
    let estimated1RM: Double
    let setsCompleted: Int

    enum CodingKeys: String, CodingKey {
        case date
        case bestWeight = "best_weight"
        case bestReps = "best_reps"
        case totalVolume = "total_volume"
        case estimated1RM = "estimated_1rm"
        case setsCompleted = "sets_completed"
    }
}

// MARK: - Weight Tracking

struct WeightEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let value: Double
}

struct WeightSummaryResponse: Codable {
    let entries: [WeightEntry]
    let current: Double?
    let goal: Double?
    let trendDirection: String?
    let weeklyAvg: Double?
    let changeFromStart: Double?

    enum CodingKeys: String, CodingKey {
        case entries, current, goal
        case trendDirection = "trend_direction"
        case weeklyAvg = "weekly_avg"
        case changeFromStart = "change_from_start"
    }
}

// MARK: - Review

struct ReviewResponse: Codable {
    let period: String
    let startDate: String
    let endDate: String
    let workoutsCompleted: Int
    let workoutsPlanned: Int
    let totalVolume: Double
    let volumeChangePct: Double
    let prs: [[String: AnyCodable]]
    let nutritionAdherencePct: Double
    let avgCalories: Double
    let avgProtein: Double
    let avgSleepHours: Double
    let sleepConsistency: Double
    let weightStart: Double?
    let weightEnd: Double?
    let weightChange: Double?
    let highlights: [String]
    let overallScore: Double

    enum CodingKeys: String, CodingKey {
        case period, prs, highlights
        case startDate = "start_date"
        case endDate = "end_date"
        case workoutsCompleted = "workouts_completed"
        case workoutsPlanned = "workouts_planned"
        case totalVolume = "total_volume"
        case volumeChangePct = "volume_change_pct"
        case nutritionAdherencePct = "nutrition_adherence_pct"
        case avgCalories = "avg_calories"
        case avgProtein = "avg_protein"
        case avgSleepHours = "avg_sleep_hours"
        case sleepConsistency = "sleep_consistency"
        case weightStart = "weight_start"
        case weightEnd = "weight_end"
        case weightChange = "weight_change"
        case overallScore = "overall_score"
    }
}

// MARK: - Smart Dashboard

struct DashboardResponse: Codable {
    let enhancedRecovery: EnhancedRecoveryResponse
    let readinessScore: Double
    let readinessIntensity: String
    let progress: ProgressSummary
    let recommendations: [SmartRecommendation]
    let weeklySummary: WeeklySummary

    enum CodingKeys: String, CodingKey {
        case enhancedRecovery = "enhanced_recovery"
        case readinessScore = "readiness_score"
        case readinessIntensity = "readiness_intensity"
        case progress
        case recommendations
        case weeklySummary = "weekly_summary"
    }
}

struct RecoveryFactor: Codable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let score: Double
    let impact: String
    let recommendation: String?

    var impactColor: Color {
        switch impact {
        case "positive": return .green
        case "negative": return .red
        default: return .orange
        }
    }

    var displayName: String {
        switch name {
        case "sleep_hours": return "Sleep"
        case "training_load": return "Training Load"
        case "hrv": return "HRV"
        default: return name.capitalized
        }
    }

    var icon: String {
        switch name {
        case "sleep_hours": return "bed.double.fill"
        case "training_load": return "dumbbell.fill"
        case "hrv": return "heart.fill"
        default: return "chart.bar.fill"
        }
    }
}

struct EnhancedRecoveryResponse: Codable {
    let score: Double
    let status: String
    let factors: [RecoveryFactor]
    let primaryRecommendation: String
    let sleepDeficitHours: Double?
    let estimatedFullRecoveryHours: Int?

    enum CodingKeys: String, CodingKey {
        case score, status, factors
        case primaryRecommendation = "primary_recommendation"
        case sleepDeficitHours = "sleep_deficit_hours"
        case estimatedFullRecoveryHours = "estimated_full_recovery_hours"
    }

    var statusColor: Color {
        switch status {
        case "recovered": return .green
        case "moderate": return .orange
        case "fatigued": return .red
        default: return .gray
        }
    }
}

struct LiftProgress: Codable, Identifiable {
    var id: String { exerciseName }
    let exerciseName: String
    let currentValue: Double
    let changeValue: Double
    let changePercent: Double
    let period: String

    enum CodingKeys: String, CodingKey {
        case exerciseName = "exercise_name"
        case currentValue = "current_value"
        case changeValue = "change_value"
        case changePercent = "change_percent"
        case period
    }

    var changeColor: Color {
        if changeValue > 0 { return .green }
        if changeValue < 0 { return .red }
        return .secondary
    }

    var changeSymbol: String {
        if changeValue > 0 { return "+" }
        return ""
    }
}

struct MuscleBalance: Codable, Identifiable {
    var id: String { category }
    let category: String
    let volume7d: Double
    let daysSinceTrained: Int?
    let status: String

    enum CodingKeys: String, CodingKey {
        case category
        case volume7d = "volume_7d"
        case daysSinceTrained = "days_since_trained"
        case status
    }

    var statusColor: Color {
        switch status {
        case "recovered": return .green
        case "recovering": return .orange
        case "needs_attention": return .red
        default: return .gray
        }
    }
}

struct ProgressSummary: Codable {
    let keyLifts: [LiftProgress]
    let totalVolumeWeek: Double
    let volumeTrendPct: Double
    let recentPrs: [[String: AnyCodable]]
    let muscleBalance: [MuscleBalance]

    enum CodingKeys: String, CodingKey {
        case keyLifts = "key_lifts"
        case totalVolumeWeek = "total_volume_week"
        case volumeTrendPct = "volume_trend_pct"
        case recentPrs = "recent_prs"
        case muscleBalance = "muscle_balance"
    }

    var volumeTrendColor: Color {
        if volumeTrendPct > 5 { return .green }
        if volumeTrendPct < -5 { return .red }
        return .secondary
    }
}

struct SmartRecommendation: Codable, Identifiable {
    let id: String
    let category: String
    let priority: Int
    let title: String
    let message: String
    let actionRoute: String?

    enum CodingKeys: String, CodingKey {
        case id, category, priority, title, message
        case actionRoute = "action_route"
    }

    var categoryColor: Color {
        switch category {
        case "workout": return .green
        case "sleep": return .indigo
        case "nutrition": return .orange
        case "recovery": return .blue
        default: return .gray
        }
    }

    var categoryIcon: String {
        switch category {
        case "workout": return "dumbbell.fill"
        case "sleep": return "bed.double.fill"
        case "nutrition": return "fork.knife"
        case "recovery": return "heart.circle.fill"
        default: return "lightbulb.fill"
        }
    }
}

struct WeeklySummary: Codable {
    let workoutsCompleted: Int
    let workoutsPlanned: Int
    let avgSleepScore: Double
    let nutritionAdherencePct: Double
    let bestDay: String?
    let highlights: [String]

    enum CodingKeys: String, CodingKey {
        case workoutsCompleted = "workouts_completed"
        case workoutsPlanned = "workouts_planned"
        case avgSleepScore = "avg_sleep_score"
        case nutritionAdherencePct = "nutrition_adherence_pct"
        case bestDay = "best_day"
        case highlights
    }

    var workoutCompletionPct: Double {
        guard workoutsPlanned > 0 else { return 0 }
        return Double(workoutsCompleted) / Double(workoutsPlanned) * 100
    }
}

// MARK: - Narrative Dashboard (Phase 11B)

struct CausalAnnotation: Codable, Identifiable {
    var id: String { metricName }
    let metricName: String
    let currentValue: Double
    let primaryDriver: String
    let driverFactor: String
    let driverImpactPct: Double
    let secondaryDriver: String?

    enum CodingKeys: String, CodingKey {
        case metricName = "metric_name"
        case currentValue = "current_value"
        case primaryDriver = "primary_driver"
        case driverFactor = "driver_factor"
        case driverImpactPct = "driver_impact_pct"
        case secondaryDriver = "secondary_driver"
    }
}

struct CommitmentSlot: Codable, Identifiable {
    var id: String { slot }
    let slot: String
    let title: String
    let subtitle: String
    let icon: String
    let category: String
    let actionRoute: String?
    let loadModifier: String?

    enum CodingKeys: String, CodingKey {
        case slot, title, subtitle, icon, category
        case actionRoute = "action_route"
        case loadModifier = "load_modifier"
    }

    var slotLabel: String {
        switch slot {
        case "now": return "NOW"
        case "next": return "NEXT"
        case "tonight": return "TONIGHT"
        default: return slot.uppercased()
        }
    }

    var slotColor: Color {
        switch slot {
        case "now": return AppTheme.primary
        case "next": return .orange
        case "tonight": return .indigo
        default: return .gray
        }
    }
}

struct DailyAction: Codable, Identifiable {
    let id: String
    let title: String
    let prompt: String?
    let icon: String
    let actionRoute: String
    let isCompleted: Bool
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case id, title, prompt, icon, priority
        case actionRoute = "action_route"
        case isCompleted = "is_completed"
    }
}

struct PrioritizedCard: Codable, Identifiable, Equatable {
    var id: String { cardType }
    let cardType: String
    let priority: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
        case priority, reason
    }
}

struct NarrativeDashboardResponse: Codable {
    let enhancedRecovery: EnhancedRecoveryResponse
    let readinessScore: Double
    let readinessIntensity: String
    let progress: ProgressSummary
    let recommendations: [SmartRecommendation]
    let weeklySummary: WeeklySummary
    let causalAnnotations: [CausalAnnotation]
    let commitments: [CommitmentSlot]
    let cardPriorityOrder: [PrioritizedCard]
    let greetingContext: String
    let readinessNarrative: String
    let dailyActions: [DailyAction]

    enum CodingKeys: String, CodingKey {
        case enhancedRecovery = "enhanced_recovery"
        case readinessScore = "readiness_score"
        case readinessIntensity = "readiness_intensity"
        case progress, recommendations
        case weeklySummary = "weekly_summary"
        case causalAnnotations = "causal_annotations"
        case commitments
        case cardPriorityOrder = "card_priority_order"
        case greetingContext = "greeting_context"
        case readinessNarrative = "readiness_narrative"
        case dailyActions = "daily_actions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enhancedRecovery = try container.decode(EnhancedRecoveryResponse.self, forKey: .enhancedRecovery)
        readinessScore = try container.decode(Double.self, forKey: .readinessScore)
        readinessIntensity = try container.decode(String.self, forKey: .readinessIntensity)
        progress = try container.decode(ProgressSummary.self, forKey: .progress)
        recommendations = try container.decode([SmartRecommendation].self, forKey: .recommendations)
        weeklySummary = try container.decode(WeeklySummary.self, forKey: .weeklySummary)
        causalAnnotations = try container.decode([CausalAnnotation].self, forKey: .causalAnnotations)
        commitments = try container.decode([CommitmentSlot].self, forKey: .commitments)
        cardPriorityOrder = try container.decode([PrioritizedCard].self, forKey: .cardPriorityOrder)
        greetingContext = try container.decode(String.self, forKey: .greetingContext)
        readinessNarrative = try container.decode(String.self, forKey: .readinessNarrative)
        dailyActions = try container.decodeIfPresent([DailyAction].self, forKey: .dailyActions) ?? []
    }
}

// MARK: - Metabolic Readiness (Phase 12B)

struct DailyTargetsDetail: Codable {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let isTrainingDay: Bool

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case isTrainingDay = "is_training_day"
    }
}

struct AdjustmentReason: Codable, Identifiable {
    var id: String { factor }
    let factor: String
    let adjustment: String
    let explanation: String
}

struct DeficitStatus: Codable {
    let caloriesConsumed: Double
    let caloriesTarget: Double
    let caloriesRemaining: Double
    let proteinConsumedG: Double
    let proteinTargetG: Double
    let proteinRemainingG: Double
    let urgency: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case caloriesConsumed = "calories_consumed"
        case caloriesTarget = "calories_target"
        case caloriesRemaining = "calories_remaining"
        case proteinConsumedG = "protein_consumed_g"
        case proteinTargetG = "protein_target_g"
        case proteinRemainingG = "protein_remaining_g"
        case urgency, message
    }
}

struct ReadinessTargetsResponse: Codable {
    let date: String
    let readinessScore: Double
    let isTrainingDay: Bool
    let base: DailyTargetsDetail
    let adjusted: DailyTargetsDetail
    let adjustments: [AdjustmentReason]
    let deficit: DeficitStatus

    enum CodingKeys: String, CodingKey {
        case date
        case readinessScore = "readiness_score"
        case isTrainingDay = "is_training_day"
        case base, adjusted, adjustments, deficit
    }
}

// Helper for decoding dynamic JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}
