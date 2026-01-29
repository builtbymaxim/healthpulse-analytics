//
//  AuthService.swift
//  HealthPulse
//
//  Authentication service using Supabase
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    private let supabaseURL: String
    private let supabaseAnonKey: String

    private init() {
        self.supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? "https://your-project.supabase.co"
        self.supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? "your-anon-key"

        // Check for stored session
        checkStoredSession()
    }

    private func checkStoredSession() {
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            APIService.shared.setAuthToken(token)
            isAuthenticated = true
            Task {
                await loadProfile()
            }
        }
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let body: [String: String] = ["email": email, "password": password]
            let response = try await supabaseRequest(
                endpoint: "/auth/v1/signup",
                method: "POST",
                body: body
            )

            if let accessToken = response["access_token"] as? String {
                await handleAuthSuccess(token: accessToken)
            } else {
                error = "Check your email for confirmation link"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let body: [String: String] = [
                "email": email,
                "password": password,
                "grant_type": "password"
            ]
            let response = try await supabaseRequest(
                endpoint: "/auth/v1/token?grant_type=password",
                method: "POST",
                body: body
            )

            if let accessToken = response["access_token"] as? String {
                await handleAuthSuccess(token: accessToken)
            } else {
                error = "Invalid credentials"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
        APIService.shared.setAuthToken(nil)
        isAuthenticated = false
        currentUser = nil
    }

    private func handleAuthSuccess(token: String) async {
        UserDefaults.standard.set(token, forKey: "auth_token")
        APIService.shared.setAuthToken(token)
        isAuthenticated = true
        await loadProfile()
    }

    private func loadProfile() async {
        do {
            currentUser = try await APIService.shared.getProfile()
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    private func supabaseRequest(
        endpoint: String,
        method: String,
        body: [String: String]
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(supabaseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.unauthorized
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        return json
    }
}
