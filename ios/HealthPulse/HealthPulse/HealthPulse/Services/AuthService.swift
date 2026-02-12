//
//  AuthService.swift
//  HealthPulse
//
//  Authentication service using backend API
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var isOnboardingComplete = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    private init() {
        checkStoredSession()
        setupAuthFailureListener()
        setupTokenRefreshListener()
    }

    private func setupAuthFailureListener() {
        NotificationCenter.default.addObserver(
            forName: .authenticationFailed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthFailure()
            }
        }
    }

    private func setupTokenRefreshListener() {
        NotificationCenter.default.addObserver(
            forName: .tokensRefreshed,
            object: nil,
            queue: .main
        ) { notification in
            let accessToken = notification.userInfo?["access_token"] as? String
            let refreshToken = notification.userInfo?["refresh_token"] as? String
            Task { @MainActor in
                if let accessToken {
                    KeychainService.save(key: "auth_token", value: accessToken)
                }
                if let refreshToken {
                    KeychainService.save(key: "refresh_token", value: refreshToken)
                }
            }
        }
    }

    private func handleAuthFailure() {
        // Clear auth state and redirect to login
        print("Auth failure detected - logging out")
        signOut()
        isOnboardingComplete = false
        ToastManager.shared.error("Session expired. Please log in again.")
    }

    private func checkStoredSession() {
        // Migrate legacy UserDefaults token to Keychain
        if let legacyToken = UserDefaults.standard.string(forKey: "auth_token") {
            KeychainService.save(key: "auth_token", value: legacyToken)
            UserDefaults.standard.removeObject(forKey: "auth_token")
        }

        if let token = KeychainService.load(key: "auth_token") {
            APIService.shared.setAuthToken(token)
            if let refreshToken = KeychainService.load(key: "refresh_token") {
                APIService.shared.setRefreshToken(refreshToken)
            }
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
            let response = try await APIService.shared.signUp(email: email, password: password)

            if let token = response.accessToken {
                await handleAuthSuccess(token: token, refreshToken: response.refreshToken)
            } else if response.requiresConfirmation == true {
                error = "Check your email for confirmation link"
            } else {
                error = "Sign up failed"
            }
        } catch let apiError as APIError {
            self.error = apiError.message
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await APIService.shared.signIn(email: email, password: password)
            if let token = response.accessToken {
                await handleAuthSuccess(token: token, refreshToken: response.refreshToken)
            } else {
                error = "Sign in failed"
            }
        } catch let apiError as APIError {
            self.error = apiError.message
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        KeychainService.delete(key: "auth_token")
        KeychainService.delete(key: "refresh_token")
        APIService.shared.setAuthToken(nil)
        APIService.shared.setRefreshToken(nil)
        isAuthenticated = false
        currentUser = nil
    }

    private func handleAuthSuccess(token: String, refreshToken: String? = nil) async {
        KeychainService.save(key: "auth_token", value: token)
        APIService.shared.setAuthToken(token)
        if let refreshToken = refreshToken {
            KeychainService.save(key: "refresh_token", value: refreshToken)
            APIService.shared.setRefreshToken(refreshToken)
        }
        isAuthenticated = true
        await loadProfile()
    }

    func loadProfile() async {
        do {
            currentUser = try await APIService.shared.getProfile()
            // Check if onboarding is complete (user has set basic profile info)
            isOnboardingComplete = currentUser?.isProfileComplete ?? false
        } catch {
            print("Failed to load profile: \(error)")
            // If profile load fails, assume onboarding needed
            isOnboardingComplete = false
        }
    }
}
