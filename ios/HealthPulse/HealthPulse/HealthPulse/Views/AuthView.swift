//
//  AuthView.swift
//  HealthPulse
//
//  Login and signup view
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var heartbeatPhase: Int = 0
    @State private var heartbeatTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()

                VStack(spacing: 32) {
                    // Logo with heartbeat animation and glow
                    VStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280)
                            .scaleEffect(heartbeatScale)
                            .shadow(color: AppTheme.primary.opacity(0.4), radius: 30, x: 0, y: 0)
                            .onAppear {
                                startHeartbeat()
                            }
                            .onDisappear {
                                heartbeatTimer?.invalidate()
                                heartbeatTimer = nil
                            }

                        Text("Track. Train. Transform.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Glassmorphism form card
                    VStack(spacing: 20) {
                        // Form fields
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )

                            SecureField("Password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )

                            if isSignUp {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }

                        // Error message
                        if let error = authService.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        // Submit button
                        Button {
                            HapticsManager.shared.medium()
                            Task {
                                if isSignUp {
                                    await authService.signUp(email: email, password: password)
                                } else {
                                    await authService.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? AppTheme.primary : Color.gray.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(!isFormValid || authService.isLoading)

                        // Toggle sign up / sign in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isSignUp.toggle()
                                authService.error = nil
                            }
                            HapticsManager.shared.light()
                        } label: {
                            if isSignUp {
                                Text("Already have an account? Sign In")
                            } else {
                                Text("Don't have an account? Sign Up")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
        return !email.isEmpty && !password.isEmpty
    }

    // Heartbeat animation - double pulse then pause
    private var heartbeatScale: CGFloat {
        switch heartbeatPhase {
        case 1: return 1.08  // First beat (big)
        case 2: return 1.0   // Release
        case 3: return 1.05  // Second beat (small)
        case 4: return 1.0   // Release
        default: return 1.0  // Rest
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.12)) {
                heartbeatPhase += 1
                if heartbeatPhase > 10 {  // 4 beats + 6 rest phases = ~1.5s cycle
                    heartbeatPhase = 0
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService.shared)
}
