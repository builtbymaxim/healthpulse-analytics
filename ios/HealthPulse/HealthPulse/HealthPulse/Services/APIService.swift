//
//  APIService.swift
//  HealthPulse
//
//  API client for backend communication
//

import Foundation
import CryptoKit

extension Notification.Name {
    static let authenticationFailed = Notification.Name("authenticationFailed")
    static let tokensRefreshed = Notification.Name("tokensRefreshed")
}

// MARK: - Certificate Pinning Delegate

/// Validates server certificates against pinned SPKI hashes.
/// Ships with an empty pin set (passthrough) until production hashes are confirmed.
/// To activate: extract the SPKI SHA-256 hash with:
///   openssl s_client -connect <host>:443 </dev/null 2>/dev/null | \
///   openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | \
///   openssl dgst -sha256 -binary | base64
private class PinningDelegate: NSObject, URLSessionDelegate {
    /// Add SPKI SHA-256 hashes here for production pinning.
    /// Empty = passthrough (no pinning enforced).
    static let pinnedKeyHashes: Set<Data> = []

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Standard certificate chain validation first
        var cfError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If no pins configured, allow (dev mode or pre-activation)
        guard !Self.pinnedKeyHashes.isEmpty else {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        // Extract server leaf certificate public key and hash it
        guard
            let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
            let leafCert = certChain.first,
            let publicKey = SecCertificateCopyKey(leafCert),
            let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let keyHash = Data(SHA256.hash(data: publicKeyData))
        if Self.pinnedKeyHashes.contains(keyHash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - API Service

class APIService {
    static let shared = APIService()

    private let baseURL: String
    private var authToken: String?
    private var refreshToken: String?
    private let refreshCoordinator = TokenRefreshCoordinator()
    private let session: URLSession

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
        let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
        self.baseURL = envURL ?? "https://healthpulse-analytics-production.up.railway.app/api/v1"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30   // per-request timeout
        config.timeoutIntervalForResource = 60  // total resource timeout
        config.waitsForConnectivity = true       // wait briefly before failing on no network

        // Attach pinning delegate only in production (skip for local dev overrides)
        if envURL != nil {
            // Local dev: no pinning
            self.session = URLSession(configuration: config)
        } else {
            self.session = URLSession(
                configuration: config,
                delegate: PinningDelegate(),
                delegateQueue: nil
            )
        }
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func setRefreshToken(_ token: String?) {
        self.refreshToken = token
    }

    /// Attempt to refresh the access token using the stored refresh token.
    /// Returns true if refresh succeeded, false if it failed (should logout).
    private func refreshAccessToken() async -> Bool {
        guard refreshToken != nil else { return false }

        // Use the coordinator to serialize concurrent refresh attempts.
        // Read refreshToken INSIDE the closure so queued callers pick up the
        // updated token after the first refresh succeeds.
        return await refreshCoordinator.refresh { [weak self] in
            guard let self = self,
                  let currentRefreshToken = self.refreshToken else { return false }

            guard let url = URL(string: "\(self.baseURL)/auth/refresh") else { return false }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            struct RefreshBody: Encodable { let refresh_token: String }
            req.httpBody = try? self.encoder.encode(RefreshBody(refresh_token: currentRefreshToken))

            guard let (data, response) = try? await session.data(for: req),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let authResponse = try? self.decoder.decode(AuthResponse.self, from: data),
                  let newAccessToken = authResponse.accessToken else {
                return false
            }

            self.authToken = newAccessToken
            self.refreshToken = authResponse.refreshToken

            // Notify AuthService to persist the new tokens in Keychain
            NotificationCenter.default.post(
                name: .tokensRefreshed,
                object: nil,
                userInfo: [
                    "access_token": newAccessToken,
                    "refresh_token": authResponse.refreshToken as Any
                ]
            )
            return true
        }
    }

    /// Public wrapper for proactive token refresh from AuthService.
    func refreshAccessTokenPublic() async -> Bool {
        await refreshAccessToken()
    }

    // MARK: - Retry Wrapper

    /// Retries a request on transient failures (5xx, network timeout, connection lost).
    /// Does NOT retry auth errors, 4xx validation errors, or offline state — those propagate immediately.
    func requestWithRetry<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        maxRetries: Int = 3
    ) async throws -> T {
        var lastError: Error = APIError.serverError
        for attempt in 0..<maxRetries {
            do {
                return try await request(endpoint: endpoint, method: method, body: body)
            } catch APIError.serverError {
                lastError = APIError.serverError
            } catch let urlError as URLError
                where urlError.code == .timedOut || urlError.code == .networkConnectionLost {
                lastError = urlError
            } catch {
                // 4xx, auth, validation, offline — don't retry
                throw error
            }
            if attempt < maxRetries - 1 {
                let delayNs = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        throw lastError
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard NetworkMonitor.shared.isCurrentlyConnected else {
            throw APIError.offline
        }
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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            // Attempt silent token refresh before logging out
            print("API 401 Unauthorized for \(endpoint) — attempting token refresh")
            if await refreshAccessToken() {
                // Retry the original request with the new token
                var retryRequest = request
                if let newToken = authToken {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse, (200...299).contains(retryHttp.statusCode) {
                    return try decoder.decode(T.self, from: retryData)
                }
            }
            // Refresh failed or retry failed — force logout
            print("Token refresh failed for \(endpoint) — logging out")
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
        guard NetworkMonitor.shared.isCurrentlyConnected else {
            throw APIError.offline
        }
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

        let (data, response) = try await session.data(for: request)

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
            print("API 401 Unauthorized for \(endpoint) — attempting token refresh")
            if await refreshAccessToken() {
                var retryRequest = request
                if let newToken = authToken {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                if let retryHttp = retryResponse as? HTTPURLResponse, (200...299).contains(retryHttp.statusCode) {
                    if let str = String(data: retryData, encoding: .utf8), str.trimmingCharacters(in: .whitespaces) == "null" {
                        return nil
                    }
                    if retryData.isEmpty { return nil }
                    return try decoder.decode(T.self, from: retryData)
                }
            }
            print("Token refresh failed for \(endpoint) — logging out")
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

    func getDashboardData() async throws -> DashboardResponse {
        try await request(endpoint: "/predictions/dashboard")
    }

    func getNarrativeDashboard() async throws -> NarrativeDashboardResponse {
        try await request(endpoint: "/predictions/dashboard/narrative")
    }

    // MARK: - Metrics

    func logMetric(_ metric: HealthMetric) async throws -> HealthMetric {
        try await request(endpoint: "/metrics", method: "POST", body: metric)
    }

    struct MetricBatchItem: Encodable {
        let metricType: String
        let value: Double
        let unit: String?
        let source: String

        enum CodingKeys: String, CodingKey {
            case metricType = "metric_type"
            case value, unit, source
        }
    }

    struct MetricBatchRequest: Encodable {
        let metrics: [MetricBatchItem]
    }

    func logMetricsBatch(_ items: [MetricBatchItem]) async throws {
        struct BatchResponse: Decodable { let id: UUID }
        let _: [BatchResponse] = try await request(
            endpoint: "/metrics/batch",
            method: "POST",
            body: MetricBatchRequest(metrics: items)
        )
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

    func getUnifiedWorkouts(days: Int = 30, limit: Int = 20) async throws -> [UnifiedWorkoutEntry] {
        try await request(endpoint: "/workouts/unified?days=\(days)&limit=\(limit)")
    }

    func deleteWorkout(id: UUID) async throws {
        let _: EmptyResponse = try await request(endpoint: "/workouts/\(id)", method: "DELETE")
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

    // MARK: - Account Management

    struct MessageResponse: Decodable {
        let message: String
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> MessageResponse {
        struct Body: Encodable {
            let currentPassword: String
            let newPassword: String
            enum CodingKeys: String, CodingKey {
                case currentPassword = "current_password"
                case newPassword = "new_password"
            }
        }
        return try await request(endpoint: "/account/change-password", method: "POST", body: Body(currentPassword: currentPassword, newPassword: newPassword))
    }

    func changeEmail(newEmail: String, currentPassword: String) async throws -> MessageResponse {
        struct Body: Encodable {
            let newEmail: String
            let currentPassword: String
            enum CodingKeys: String, CodingKey {
                case newEmail = "new_email"
                case currentPassword = "current_password"
            }
        }
        return try await request(endpoint: "/account/change-email", method: "POST", body: Body(newEmail: newEmail, currentPassword: currentPassword))
    }

    func updateAvatar(_ symbol: String) async throws {
        struct Body: Encodable {
            let avatarUrl: String
            enum CodingKeys: String, CodingKey {
                case avatarUrl = "avatar_url"
            }
        }
        let _: User = try await request(endpoint: "/users/me", method: "PUT", body: Body(avatarUrl: symbol))
    }

    func updateDisplayNameAndAvatar(displayName: String, avatarUrl: String) async throws {
        struct Body: Encodable {
            let displayName: String
            let avatarUrl: String
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case avatarUrl = "avatar_url"
            }
        }
        let _: User = try await request(endpoint: "/users/me", method: "PUT", body: Body(displayName: displayName, avatarUrl: avatarUrl))
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

    func updateDietaryPreferences(
        dietaryPattern: String?,
        allergies: [String]?,
        mealsPerDay: Int?,
        experienceLevel: String?,
        motivation: String?,
        bodyFatPct: Double?
    ) async throws {
        struct DietaryUpdate: Encodable {
            let dietaryPattern: String?
            let allergies: [String]?
            let mealsPerDay: Int?
            let experienceLevel: String?
            let motivation: String?
            let bodyFatPct: Double?

            enum CodingKeys: String, CodingKey {
                case dietaryPattern = "dietary_pattern"
                case allergies
                case mealsPerDay = "meals_per_day"
                case experienceLevel = "experience_level"
                case motivation
                case bodyFatPct = "body_fat_pct"
            }
        }
        let body = DietaryUpdate(
            dietaryPattern: dietaryPattern,
            allergies: allergies,
            mealsPerDay: mealsPerDay,
            experienceLevel: experienceLevel,
            motivation: motivation,
            bodyFatPct: bodyFatPct
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

    func updateFood(entryId: UUID, update: FoodEntryUpdate) async throws -> FoodEntry {
        try await request(endpoint: "/nutrition/food/\(entryId)", method: "PUT", body: update)
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

    func getTemplateDetails(templateId: UUID) async throws -> PlanTemplate {
        try await request(endpoint: "/training-plans/templates/\(templateId)")
    }

    func activateTrainingPlan(templateId: UUID, schedule: [String: String]) async throws -> ActivatePlanResponse {
        let body = ActivatePlanRequest(templateId: templateId, schedule: schedule)
        return try await request(endpoint: "/training-plans/activate", method: "POST", body: body)
    }

    func deactivateTrainingPlan() async throws -> EmptyResponse {
        try await request(endpoint: "/training-plans/active", method: "DELETE")
    }

    func updateTrainingPlan(planId: UUID, name: String? = nil, schedule: [String: String]? = nil, customizations: [String: [String: String]]? = nil) async throws -> UpdatePlanResponse {
        let body = UpdatePlanRequest(name: name, schedule: schedule, customizations: customizations)
        return try await request(endpoint: "/training-plans/\(planId)", method: "PUT", body: body)
    }

    func logWorkoutSession(_ session: WorkoutSessionRequest) async throws -> WorkoutSessionResponse {
        try await request(endpoint: "/training-plans/sessions", method: "POST", body: session)
    }

    func getWorkoutSessions(days: Int = 30) async throws -> [WorkoutSession] {
        try await request(endpoint: "/training-plans/sessions?days=\(days)")
    }

    func getExerciseProgress(exerciseName: String, days: Int = 90) async throws -> ExerciseProgressResponse {
        let encoded = exerciseName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? exerciseName
        return try await request(endpoint: "/training-plans/progress/\(encoded)?days=\(days)")
    }

    func getExerciseSuggestions(exerciseNames: [String]) async throws -> [String: WeightSuggestion] {
        let body = ["exercise_names": exerciseNames]
        return try await request(endpoint: "/training-plans/suggestions", method: "POST", body: body)
    }

    func createCustomPlan(_ request: CreateCustomPlanRequest) async throws -> CreateCustomPlanResponse {
        try await self.request(endpoint: "/training-plans/custom", method: "POST", body: request)
    }

    func updateCustomPlan(planId: UUID, _ request: CreateCustomPlanRequest) async throws -> CreateCustomPlanResponse {
        try await self.request(endpoint: "/training-plans/custom/\(planId)", method: "PUT", body: request)
    }

    func getTrainingPlanDetail(_ id: UUID) async throws -> TrainingPlanSummary {
        try await self.request(endpoint: "/training-plans/\(id.uuidString)")
    }

    // MARK: - Weight Tracking

    func getWeightSummary(days: Int = 30) async throws -> WeightSummaryResponse {
        try await request(endpoint: "/metrics/weight-summary?days=\(days)")
    }

    // MARK: - Review

    func getReview(period: String) async throws -> ReviewResponse {
        try await request(endpoint: "/predictions/review?period=\(period)")
    }

    // MARK: - Social

    func createInviteCode() async throws -> InviteCode {
        try await request(endpoint: "/social/invite-codes", method: "POST")
    }

    func getInviteCodes() async throws -> [InviteCode] {
        try await request(endpoint: "/social/invite-codes")
    }

    func useInviteCode(_ code: String, challengeType: String, durationWeeks: Int?) async throws -> Partner {
        let body = UseInviteRequest(challengeType: challengeType, durationWeeks: durationWeeks)
        return try await request(endpoint: "/social/invite-codes/\(code)/use", method: "POST", body: body)
    }

    func getPartners() async throws -> [Partner] {
        try await request(endpoint: "/social/partners")
    }

    func acceptPartnership(_ id: UUID) async throws -> Partner {
        try await request(endpoint: "/social/partners/\(id)/accept", method: "PUT")
    }

    func declinePartnership(_ id: UUID) async throws -> EmptyResponse {
        try await request(endpoint: "/social/partners/\(id)/decline", method: "PUT")
    }

    func endPartnership(_ id: UUID) async throws -> EmptyResponse {
        try await request(endpoint: "/social/partners/\(id)", method: "DELETE")
    }

    func getLeaderboard(category: String, exerciseName: String? = nil) async throws -> [LeaderboardEntry] {
        var endpoint = "/social/leaderboard/\(category)"
        if let exerciseName = exerciseName {
            let encoded = exerciseName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exerciseName
            endpoint += "?exercise_name=\(encoded)"
        }
        return try await request(endpoint: endpoint)
    }

    func updateSocialOptIn(_ optIn: Bool) async throws {
        struct SocialSettingsUpdate: Encodable {
            let socialOptIn: Bool
            enum CodingKeys: String, CodingKey {
                case socialOptIn = "social_opt_in"
            }
        }
        let _: User = try await request(endpoint: "/users/me/settings", method: "PUT", body: SocialSettingsUpdate(socialOptIn: optIn))
    }

    // MARK: - Meal Plans & Recipes

    func getRecipes(category: String? = nil, goalType: String? = nil, search: String? = nil, tag: String? = nil) async throws -> [Recipe] {
        var params: [String] = []
        if let category { params.append("category=\(category)") }
        if let goalType { params.append("goal_type=\(goalType)") }
        if let search, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            params.append("search=\(encoded)")
        }
        if let tag { params.append("tag=\(tag)") }
        var endpoint = "/meal-plans/recipes"
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }
        return try await request(endpoint: endpoint)
    }

    func getRecipe(id: UUID) async throws -> Recipe {
        try await request(endpoint: "/meal-plans/recipes/\(id)")
    }

    func getMealPlanTemplates(goalType: String? = nil) async throws -> [MealPlanTemplate] {
        var endpoint = "/meal-plans/templates"
        if let goalType { endpoint += "?goal_type=\(goalType)" }
        return try await request(endpoint: endpoint)
    }

    func getMealPlanTemplate(id: UUID) async throws -> MealPlanTemplate {
        try await request(endpoint: "/meal-plans/templates/\(id)")
    }

    func quickAddRecipe(_ request: QuickAddRecipeRequest) async throws -> FoodEntry {
        try await self.request(endpoint: "/meal-plans/quick-add", method: "POST", body: request)
    }

    func getRecipeSuggestions(mealType: String? = nil) async throws -> [Recipe] {
        var endpoint = "/meal-plans/suggestions"
        if let mealType { endpoint += "?meal_type=\(mealType)" }
        return try await request(endpoint: endpoint)
    }

    func getReadinessTargets(date: Date? = nil) async throws -> ReadinessTargetsResponse {
        var endpoint = "/nutrition/readiness-targets"
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endpoint += "?date=\(formatter.string(from: date))"
        }
        return try await request(endpoint: endpoint)
    }

    func getDeficitFixRecipes(deficitKcal: Double, deficitProteinG: Double) async throws -> [Recipe] {
        try await request(
            endpoint: "/meal-plans/suggestions/deficit-fix?deficit_kcal=\(Int(deficitKcal))&deficit_protein_g=\(Int(deficitProteinG))"
        )
    }

    func lookupBarcode(_ barcode: String) async throws -> BarcodeProduct {
        try await request(endpoint: "/meal-plans/barcode/\(barcode)")
    }

    func searchFood(query: String) async throws -> [BarcodeProduct] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(endpoint: "/meal-plans/food-search?query=\(encoded)")
    }

    func getRecipeShoppingList(recipeId: UUID, servings: Double) async throws -> [ShoppingListItem] {
        try await request(endpoint: "/meal-plans/recipes/\(recipeId)/shopping-list?servings=\(servings)")
    }

    // MARK: - AI Food Scan (Phase 12)

    func scanFood(imageBase64: String, classificationHints: [String]) async throws -> FoodScanResponse {
        let body = FoodScanRequest(imageBase64: imageBase64, classificationHints: classificationHints)
        return try await request(endpoint: "/nutrition/food/scan", method: "POST", body: body)
    }

    func lookupUSDAFood(query: String) async throws -> [USDAFood] {
        let apiKey = "DEMO_KEY"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(apiKey)&query=\(encoded)&pageSize=5&dataType=SR%20Legacy") else {
            return []
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        let (data, _) = try await session.data(for: urlRequest)
        let decoder = JSONDecoder()
        let response = try decoder.decode(USDASearchResponse.self, from: data)
        return response.foods
    }

    func getShoppingList(templateId: UUID) async throws -> [ShoppingListItem] {
        try await request(endpoint: "/meal-plans/templates/\(templateId)/shopping-list")
    }

    // MARK: - Custom Recipes

    func getCustomRecipes() async throws -> [Recipe] {
        try await request(endpoint: "/meal-plans/recipes/custom")
    }

    func createCustomRecipe(_ recipe: CustomRecipeCreate) async throws -> Recipe {
        try await request(endpoint: "/meal-plans/recipes/custom", method: "POST", body: recipe)
    }

    func deleteCustomRecipe(recipeId: UUID) async throws {
        let _: EmptyResponse = try await request(endpoint: "/meal-plans/recipes/custom/\(recipeId)", method: "DELETE")
    }

    // MARK: - Weekly Meal Plans (Phase 9A)

    func getWeeklyPlans() async throws -> [WeeklyMealPlanListItem] {
        try await request(endpoint: "/meal-plans/weekly-plans")
    }

    func getWeeklyPlan(id: UUID) async throws -> WeeklyMealPlan {
        try await request(endpoint: "/meal-plans/weekly-plans/\(id)")
    }

    func getWeeklyPlanForDate(_ weekStartDate: String) async throws -> WeeklyMealPlan? {
        try await optionalRequest(endpoint: "/meal-plans/weekly-plans/for-week?week_start_date=\(weekStartDate)")
    }

    func createWeeklyPlan(_ req: CreateWeeklyPlanRequest) async throws -> WeeklyMealPlan {
        try await request(endpoint: "/meal-plans/weekly-plans", method: "POST", body: req)
    }

    func updateWeeklyPlan(id: UUID, _ req: CreateWeeklyPlanRequest) async throws -> WeeklyMealPlan {
        try await request(endpoint: "/meal-plans/weekly-plans/\(id)", method: "PUT", body: req)
    }

    func deleteWeeklyPlan(id: UUID) async throws {
        let _: EmptyResponse = try await request(endpoint: "/meal-plans/weekly-plans/\(id)", method: "DELETE")
    }

    func upsertPlanItem(planId: UUID, _ req: UpsertPlanItemRequest) async throws -> WeeklyPlanItem {
        try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/items", method: "PUT", body: req)
    }

    func deletePlanItem(planId: UUID, itemId: UUID) async throws {
        let _: EmptyResponse = try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/items/\(itemId)", method: "DELETE")
    }

    func autoFillPlan(planId: UUID, request: AutoFillRequest) async throws -> WeeklyMealPlan {
        try await self.request(endpoint: "/meal-plans/weekly-plans/\(planId)/auto-fill", method: "POST", body: request)
    }

    func getDayMacros(planId: UUID) async throws -> [DayMacroSummary] {
        try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/macros")
    }

    func applyPlanToFoodLog(planId: UUID, mode: String) async throws -> ApplyPlanResponse {
        try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/apply", method: "POST", body: ApplyToPlanRequest(mode: mode))
    }

    func getWeeklyShoppingList(planId: UUID) async throws -> [ShoppingListItem] {
        try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/shopping-list")
    }

    func copyPlanToNextWeek(planId: UUID) async throws -> WeeklyMealPlan {
        try await request(endpoint: "/meal-plans/weekly-plans/\(planId)/copy-next-week", method: "POST")
    }

    // MARK: - Account (GDPR)

    func deleteAccount() async throws {
        let _: EmptyResponse = try await request(endpoint: "/users/me", method: "DELETE")
    }

    func exportMyData() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/users/me/export") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError
        }
        return data
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

// MARK: - Token Refresh Coordinator

/// Serializes concurrent token refresh attempts so only one refresh call
/// happens at a time. Subsequent callers wait for the in-flight result.
actor TokenRefreshCoordinator {
    private var isRefreshing = false
    private var pendingContinuations: [CheckedContinuation<Bool, Never>] = []

    func refresh(using refreshAction: @escaping () async -> Bool) async -> Bool {
        if isRefreshing {
            // Another refresh is in flight — wait for it
            return await withCheckedContinuation { continuation in
                pendingContinuations.append(continuation)
            }
        }

        isRefreshing = true
        let success = await refreshAction()
        isRefreshing = false

        // Resume all waiters with the result
        for continuation in pendingContinuations {
            continuation.resume(returning: success)
        }
        pendingContinuations.removeAll()

        return success
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
    case offline

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
        case .offline:
            return "You appear to be offline. Please check your connection."
        }
    }
}
