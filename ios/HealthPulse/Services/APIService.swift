//
//  APIService.swift
//  HealthPulse
//
//  API client for backend communication
//

import Foundation

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
        // Load from config or environment
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "http://localhost:8000/api/v1"
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
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
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

    // MARK: - User

    func getProfile() async throws -> User {
        try await request(endpoint: "/users/me")
    }

    func updateProfile(_ user: User) async throws -> User {
        try await request(endpoint: "/users/me", method: "PUT", body: user)
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in again"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}
