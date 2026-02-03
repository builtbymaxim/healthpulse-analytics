//
//  APIService.swift
//  HealthPulse
//
//  API client for backend communication
//

import Foundation

extension Notification.Name {
    static let authenticationFailed = Notification.Name("authenticationFailed")
}

class APIService {
    static let shared = APIService()

    private let baseURL: String
    private var authToken: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {
        // Production URL (Railway deployment)
        // For local development, set API_BASE_URL environment variable in Xcode scheme
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://healthpulse-analytics-production.up.railway.app/api/v1"
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            // Notify app that auth failed - should trigger logout
            print("API 401 Unauthorized for \(endpoint)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("  Response: \(errorBody)")
            }
            NotificationCenter.default.post(name: .authenticationFailed, object: nil)
            throw APIError.unauthorized
        case 404:
            print("API 404 Not Found for \(endpoint)")
            throw APIError.notFound
        case 422:
            // Validation error - log the details
            print("API 422 Validation Error for \(endpoint)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("  Response: \(errorBody)")
            }
            throw APIError.validationError
        case 500...599:
            print("API \(httpResponse.statusCode) Server Error for \(endpoint)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("  Response: \(errorBody)")
            }
            throw APIError.serverError
        default:
            print("API \(httpResponse.statusCode) Unknown Error for \(endpoint)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("  Response: \(errorBody)")
            }
            throw APIError.unknown(httpResponse.statusCode)
        }
    }

    /// Request that can return null from the backend (returns nil instead of throwing)
    private func optionalRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Check if response is null (literally "null" in JSON)
            if let str = String(data: data, encoding: .utf8), str.trimmingCharacters(in: .whitespaces) == "null" {
                return nil
            }
            // Check for empty response
            if data.isEmpty {
                return nil
            }
            return try decoder.decode(T.self, from: data)
        case 401:
            print("API 401 Unauthorized for \(endpoint)")
            NotificationCenter.default.post(name: .authenticationFailed, object: nil)
            throw APIError.unauthorized
        case 404:
            return nil  // Not found means no data
        case 422:
            throw APIError.validationError
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }

    // MARK: - Authentication

    struct AuthRequest: Encodable {
        let email: String
        let password: String
    }

    struct AuthResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let tokenType: String?
        let expiresIn: Int?
        let userId: String?
        let email: String?
        let message: String?
        let requiresConfirmation: Bool?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case userId = "user_id"
            case email
            case message
            case requiresConfirmation = "requires_confirmation"
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        let body = AuthRequest(email: email, password: password)
        return try await request(endpoint: "/auth/signup", method: "POST", body: body)
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let body = AuthRequest(email: email, password: password)
        return try await request(endpoint: "/auth/signin", method: "POST", body: body)
    }

    // MARK: - Predictions

    func getRecoveryPrediction() async throws -> RecoveryPrediction {
        try await request(endpoint: "/predictions/recovery")
    }

    func getReadinessPrediction() async throws -> ReadinessPrediction {
        try await request(endpoint: "/predictions/readiness")
    }

    func getWellnessScore(date: Date? = nil) async throws -> WellnessScore {
        var endpoint = "/predictions/wellness"
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            endpoint += "?target_date=\(formatter.string(from: date))"
        }
        return try await request(endpoint: endpoint)
    }

    func getWellnessHistory(days: Int = 30) async throws -> [WellnessScore] {
        try await request(endpoint: "/predictions/wellness/history?days=\(days)")
    }

    func getInsights(limit: Int = 10) async throws -> [Insight] {
        try await request(endpoint: "/predictions/insights?limit=\(limit)")
    }

    func getCorrelations() async throws -> [Correlation] {
        try await request(endpoint: "/predictions/correlations")
    }

    // MARK: - Metrics

    func logMetric(_ metric: HealthMetric) async throws -> HealthMetric {
        try await request(endpoint: "/metrics", method: "POST", body: metric)
    }

    func getMetrics(type: MetricType? = nil, days: Int = 7) async throws -> [HealthMetric] {
        var endpoint = "/metrics?days=\(days)"
        if let type = type {
            endpoint += "&metric_type=\(type.rawValue)"
        }
        return try await request(endpoint: endpoint)
    }

    // MARK: - Workouts

    func logWorkout(_ workout: Workout) async throws -> Workout {
        try await request(endpoint: "/workouts", method: "POST", body: workout)
    }

    func getWorkouts(days: Int = 30) async throws -> [Workout] {
        try await request(endpoint: "/workouts?days=\(days)")
    }

    // MARK: - Exercises

    func getExercises(category: ExerciseCategory? = nil, search: String? = nil) async throws -> [Exercise] {
        var endpoint = "/exercises/"
        var params: [String] = []

        if let category = category {
            params.append("category=\(category.rawValue)")
        }
        if let search = search, !search.isEmpty {
            params.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }

        if !params.isEmpty {
            endpoint += "?" + params.joined(separator: "&")
        }

        return try await request(endpoint: endpoint)
    }

    func getExercise(id: UUID) async throws -> Exercise {
        try await request(endpoint: "/exercises/\(id)")
    }

    func getExerciseHistory(exerciseId: UUID, days: Int = 90) async throws -> ExerciseHistory {
        try await request(endpoint: "/exercises/\(exerciseId)/history?days=\(days)")
    }

    func logWorkoutSets(workoutId: UUID?, sets: [WorkoutSetCreate]) async throws -> [WorkoutSet] {
        let body = WorkoutSetsRequest(workoutId: workoutId, sets: sets)
        return try await request(endpoint: "/exercises/sets", method: "POST", body: body)
    }

    func getWorkoutSets(workoutId: UUID) async throws -> [WorkoutSet] {
        try await request(endpoint: "/exercises/workouts/\(workoutId)/sets")
    }

    func getPersonalRecords(exerciseId: UUID? = nil) async throws -> [PersonalRecord] {
        var endpoint = "/exercises/personal-records"
        if let exerciseId = exerciseId {
            endpoint += "?exercise_id=\(exerciseId)"
        }
        return try await request(endpoint: endpoint)
    }

    func getVolumeAnalytics(period: String = "week") async throws -> VolumeAnalytics {
        try await request(endpoint: "/exercises/analytics/volume?period=\(period)")
    }

    func getFrequencyAnalytics(period: String = "week") async throws -> FrequencyAnalytics {
        try await request(endpoint: "/exercises/analytics/frequency?period=\(period)")
    }

    func getMuscleGroupStats() async throws -> [MuscleGroupStats] {
        try await request(endpoint: "/exercises/analytics/muscle-groups")
    }

    // MARK: - User

    func getProfile() async throws -> User {
        try await request(endpoint: "/users/me")
    }

    func updateProfile(_ user: User) async throws -> User {
        try await request(endpoint: "/users/me", method: "PUT", body: user)
    }

    func saveOnboardingProfile(_ profile: OnboardingProfile) async throws -> User {
        try await request(endpoint: "/users/me/onboarding", method: "POST", body: profile)
    }

    func updateUserProfile(age: Int, heightCm: Double, gender: String, activityLevel: String, fitnessGoal: String) async throws {
        struct ProfileUpdate: Encodable {
            let age: Int
            let heightCm: Double
            let gender: String
            let activityLevel: String
            let fitnessGoal: String

            enum CodingKeys: String, CodingKey {
                case age
                case heightCm = "height_cm"
                case gender
                case activityLevel = "activity_level"
                case fitnessGoal = "fitness_goal"
            }
        }
        let body = ProfileUpdate(age: age, heightCm: heightCm, gender: gender, activityLevel: activityLevel, fitnessGoal: fitnessGoal)
        let _: User = try await request(endpoint: "/users/me", method: "PUT", body: body)
    }

    func updateUserSettings(hrvBaseline: Double, rhrBaseline: Double, targetSleepHours: Double, dailyStepGoal: Double) async throws {
        struct SettingsUpdate: Encodable {
            let hrvBaseline: Double
            let rhrBaseline: Double
            let targetSleepHours: Double
            let dailyStepGoal: Int

            enum CodingKeys: String, CodingKey {
                case hrvBaseline = "hrv_baseline"
                case rhrBaseline = "rhr_baseline"
                case targetSleepHours = "target_sleep_hours"
                case dailyStepGoal = "daily_step_goal"
            }
        }
        let body = SettingsUpdate(
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            targetSleepHours: targetSleepHours,
            dailyStepGoal: Int(dailyStepGoal)
        )
        let _: User = try await request(endpoint: "/users/me/settings", method: "PUT", body: body)
    }

    // MARK: - Metrics (Weight)

    func logWeight(_ weightKg: Double) async throws {
        struct MetricCreate: Encodable {
            let metricType: String
            let value: Double
            let unit: String
            let source: String

            enum CodingKeys: String, CodingKey {
                case metricType = "metric_type"
                case value, unit, source
            }
        }
        let body = MetricCreate(metricType: "weight", value: weightKg, unit: "kg", source: "manual")
        struct MetricResponse: Decodable { let id: UUID }
        let _: MetricResponse = try await request(endpoint: "/metrics/", method: "POST", body: body)
    }

    func getLatestWeight() async throws -> Double? {
        struct WeightMetric: Decodable {
            let value: Double
        }
        let metrics: [WeightMetric] = try await request(endpoint: "/metrics/?metric_type=weight&limit=1")
        return metrics.first?.value
    }

    // MARK: - Nutrition

    func getPhysicalProfile() async throws -> PhysicalProfile {
        try await request(endpoint: "/nutrition/physical-profile")
    }

    func updatePhysicalProfile(age: Int, heightCm: Double, gender: Gender, activityLevel: ActivityLevel) async throws -> PhysicalProfile {
        let body = PhysicalProfileUpdate(
            age: age,
            heightCm: heightCm,
            gender: gender.rawValue,
            activityLevel: activityLevel.rawValue
        )
        return try await request(endpoint: "/nutrition/physical-profile", method: "PUT", body: body)
    }

    func getNutritionGoal() async throws -> NutritionGoal? {
        try await request(endpoint: "/nutrition/goals")
    }

    func setNutritionGoal(_ goal: NutritionGoalCreate) async throws -> NutritionGoal {
        try await request(endpoint: "/nutrition/goals", method: "POST", body: goal)
    }

    func previewCalorieTargets(
        goalType: NutritionGoalType,
        weightKg: Double? = nil,
        age: Int? = nil,
        heightCm: Double? = nil,
        gender: String? = nil,
        activityLevel: String? = nil
    ) async throws -> CalorieTargetsPreview {
        struct PreviewRequest: Encodable {
            let goalType: String
            let weightKg: Double?
            let age: Int?
            let heightCm: Double?
            let gender: String?
            let activityLevel: String?

            enum CodingKeys: String, CodingKey {
                case goalType = "goal_type"
                case weightKg = "weight_kg"
                case age
                case heightCm = "height_cm"
                case gender
                case activityLevel = "activity_level"
            }
        }
        let body = PreviewRequest(
            goalType: goalType.rawValue,
            weightKg: weightKg,
            age: age,
            heightCm: heightCm,
            gender: gender,
            activityLevel: activityLevel
        )
        return try await request(endpoint: "/nutrition/goals/preview", method: "POST", body: body)
    }

    func logFood(_ entry: FoodEntryCreate) async throws -> FoodEntry {
        try await request(endpoint: "/nutrition/food", method: "POST", body: entry)
    }

    func getFoodEntries(date: Date? = nil) async throws -> [FoodEntry] {
        var endpoint = "/nutrition/food"
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endpoint += "?date=\(formatter.string(from: date))"
        }
        return try await request(endpoint: endpoint)
    }

    func deleteFood(entryId: UUID) async throws -> EmptyResponse {
        try await request(endpoint: "/nutrition/food/\(entryId)", method: "DELETE")
    }

    func getDailyNutritionSummary(date: Date? = nil) async throws -> DailyNutritionSummary {
        var endpoint = "/nutrition/summary"
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endpoint += "?date=\(formatter.string(from: date))"
        }
        return try await request(endpoint: endpoint)
    }

    func getWeeklyNutritionSummary() async throws -> [WeeklyNutritionDay] {
        try await request(endpoint: "/nutrition/summary/weekly")
    }

    // MARK: - Sleep

    func getSleepSummary(date: Date? = nil) async throws -> SleepSummary? {
        var endpoint = "/sleep/summary"
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endpoint += "?target_date=\(formatter.string(from: date))"
        }
        return try await optionalRequest(endpoint: endpoint)
    }

    func getSleepHistory(days: Int = 7) async throws -> [SleepEntry] {
        try await request(endpoint: "/sleep/history?days=\(days)")
    }

    func getSleepAnalytics(days: Int = 30) async throws -> SleepAnalytics {
        try await request(endpoint: "/sleep/analytics?days=\(days)")
    }

    func logSleep(_ request: SleepLogRequest) async throws -> EmptyResponse {
        try await self.request(endpoint: "/sleep/log", method: "POST", body: request)
    }

    // MARK: - Training Plans

    func getTodaysWorkout() async throws -> TodayWorkoutResponse {
        try await request(endpoint: "/training-plans/today")
    }

    func getActiveTrainingPlan() async throws -> TrainingPlanSummary? {
        try await optionalRequest(endpoint: "/training-plans/active")
    }

    func getTrainingPlanTemplates(modality: String? = nil, daysPerWeek: Int? = nil) async throws -> [PlanTemplate] {
        var endpoint = "/training-plans/templates"
        var params: [String] = []
        if let modality = modality {
            params.append("modality=\(modality)")
        }
        if let daysPerWeek = daysPerWeek {
            params.append("days_per_week=\(daysPerWeek)")
        }
        if !params.isEmpty {
            endpoint += "?" + params.joined(separator: "&")
        }
        return try await request(endpoint: endpoint)
    }
}

// Helper for empty responses
struct EmptyResponse: Decodable {
    let message: String?
}

// Weekly nutrition summary day
struct WeeklyNutritionDay: Decodable {
    let date: String
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let calorieTarget: Double
    let calorieProgressPct: Double
    let nutritionScore: Double

    enum CodingKeys: String, CodingKey {
        case date
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case calorieTarget = "calorie_target"
        case calorieProgressPct = "calorie_progress_pct"
        case nutritionScore = "nutrition_score"
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError
    case validationError
    case badRequest(String)
    case unknown(Int)

    var message: String {
        errorDescription ?? "Unknown error"
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid email or password"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later."
        case .validationError:
            return "Invalid data. Please check your input."
        case .badRequest(let msg):
            return msg
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}
