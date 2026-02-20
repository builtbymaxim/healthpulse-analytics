//
//  AuthView.swift
//  HealthPulse
//
//  Login and signup — Phase 11 premium auth flow
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // Staggered form elements
    @State private var emailOffset: CGFloat = 60
    @State private var passwordOffset: CGFloat = 60
    @State private var buttonOffset: CGFloat = 60
    @State private var emailOpacity: Double = 0
    @State private var passwordOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    // Field focus glow
    @FocusState private var focusedField: AuthField?

    // Submit shimmer
    @State private var shimmerOffset: CGFloat = -300

    // Success morph
    @State private var showSuccess: Bool = false

    enum AuthField { case email, password, confirmPassword }

    var body: some View {
        ZStack {
            // Looping video background
            LoopingVideoBackground(videoName: "AppIcon_Production_Animation")
                .ignoresSafeArea()

            // Dark scrim for form readability
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Form card ───────────────────────────────────────────────
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        // Email field
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .focused($focusedField, equals: .email)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        focusedField == .email
                                            ? AppTheme.primary.opacity(0.8)
                                            : Color.white.opacity(0.15),
                                        lineWidth: 1.5
                                    )
                                    .animation(.easeOut(duration: 0.22), value: focusedField)
                            )
                            .offset(y: emailOffset)
                            .opacity(emailOpacity)

                        // Password field
                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        focusedField == .password
                                            ? AppTheme.primary.opacity(0.8)
                                            : Color.white.opacity(0.15),
                                        lineWidth: 1.5
                                    )
                                    .animation(.easeOut(duration: 0.22), value: focusedField)
                            )
                            .offset(y: passwordOffset)
                            .opacity(passwordOpacity)

                        if isSignUp {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .padding(16)
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            focusedField == .confirmPassword
                                                ? AppTheme.primary.opacity(0.8)
                                                : Color.white.opacity(0.15),
                                            lineWidth: 1.5
                                        )
                                        .animation(.easeOut(duration: 0.22), value: focusedField)
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    // Error message
                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.error)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    // Submit button
                    Button {
                        HapticsManager.shared.medium()
                        focusedField = nil
                        Task {
                            if isSignUp {
                                await authService.signUp(email: email, password: password)
                            } else {
                                await authService.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        ZStack {
                            // Button face
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isFormValid ? AppTheme.primary : Color.white.opacity(0.10))

                            // Shimmer sweep while loading
                            if authService.isLoading {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.18),
                                                Color.white.opacity(0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: shimmerOffset)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            // Label / spinner / success
                            Group {
                                if showSuccess {
                                    Image(systemName: "checkmark")
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                        .transition(.scale.combined(with: .opacity))
                                } else if authService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.headline)
                                        .foregroundStyle(isFormValid ? .white : Color.white.opacity(0.35))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .frame(height: 52)
                    }
                    .disabled(!isFormValid || authService.isLoading)
                    .offset(y: buttonOffset)
                    .opacity(buttonOpacity)

                    // Toggle sign up / sign in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSignUp.toggle()
                            authService.error = nil
                        }
                        HapticsManager.shared.light()
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .offset(y: buttonOffset)
                    .opacity(buttonOpacity)
                }
                .padding(24)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.black.opacity(0.65))
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial.opacity(0.4))
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal)
                .elevatedShadow()

                // Tagline below form card
                Text("Track. Train. Transform.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 16)
                    .opacity(buttonOpacity)

                Spacer()
            }
        }
        .onAppear {
            runEntranceSequence()
        }
        .onChange(of: authService.isLoading) { _, isLoading in
            if isLoading {
                runShimmer()
            }
        }
    }

    // MARK: - Computed

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
        return !email.isEmpty && !password.isEmpty
    }

    // MARK: - Animation Sequences

    private func runEntranceSequence() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
            emailOffset = 0
            emailOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.38)) {
            passwordOffset = 0
            passwordOpacity = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.46)) {
            buttonOffset = 0
            buttonOpacity = 1
        }
    }

    private func runShimmer() {
        shimmerOffset = -300
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            shimmerOffset = 300
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService.shared)
}
