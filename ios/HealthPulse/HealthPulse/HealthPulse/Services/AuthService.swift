//
//  AuthService.swift
//  HealthPulse
//
//  Authentication service using backend API
//

import Foundation
import Combine
import UIKit

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var isOnboardingComplete = false
    @Published var isRestoringSession = true
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    private var refreshTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        checkStoredSession()
        setupAuthFailureListener()
        setupTokenRefreshListener()
        setupForegroundRefresh()
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

    private func setupForegroundRefresh() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isAuthenticated,
                      KeychainService.load(key: "refresh_token") != nil else { return }
                // Cancel any pending scheduled refresh to avoid double-fire
                self.refreshTask?.cancel()
                let success = await APIService.shared.refreshAccessTokenPublic()
                if success {
                    self.scheduleTokenRefresh()
                }
            }
        }
    }

    private func scheduleTokenRefresh(expiresIn: Int = 3600) {
        refreshTask?.cancel()
        let refreshDelay = max(Double(expiresIn) * 0.8, 60)
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(refreshDelay))
            guard !Task.isCancelled, let self else { return }
            let success = await APIService.shared.refreshAccessTokenPublic()
            if success {
                self.scheduleTokenRefresh(expiresIn: expiresIn)
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
            // Set from cache immediately to prevent flash
            isAuthenticated = true
            isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_complete")
            Task {
                // Refresh token to ensure it's valid, then schedule proactive refresh
                let success = await APIService.shared.refreshAccessTokenPublic()
                if success {
                    scheduleTokenRefresh()
                }
                await loadProfile()
                isRestoringSession = false
            }
        } else {
            isRestoringSession = false
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
        refreshTask?.cancel()
        refreshTask = nil
        KeychainService.delete(key: "auth_token")
        KeychainService.delete(key: "refresh_token")
        UserDefaults.standard.removeObject(forKey: "onboarding_complete")
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
        scheduleTokenRefresh()
        await loadProfile()
    }

    func loadProfile() async {
        do {
            currentUser = try await APIService.shared.getProfile()
            isOnboardingComplete = currentUser?.isProfileComplete ?? false
            UserDefaults.standard.set(isOnboardingComplete, forKey: "onboarding_complete")
        } catch {
            print("Failed to load profile: \(error)")
            // Don't reset onboarding state on network failure —
            // keep cached value to avoid flashing onboarding for established users
        }
    }
}
