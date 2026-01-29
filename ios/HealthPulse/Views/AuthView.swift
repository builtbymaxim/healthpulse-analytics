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

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("HealthPulse")
                        .font(.largeTitle.bold())

                    Text("Your Fitness & Wellness Companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                // Error message
                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Submit button
                Button {
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
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.green : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .disabled(!isFormValid || authService.isLoading)

                // Toggle sign up / sign in
                Button {
                    withAnimation {
                        isSignUp.toggle()
                        authService.error = nil
                    }
                } label: {
                    if isSignUp {
                        Text("Already have an account? Sign In")
                    } else {
                        Text("Don't have an account? Sign Up")
                    }
                }
                .font(.subheadline)

                Spacer()
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
        return !email.isEmpty && !password.isEmpty
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService.shared)
}
