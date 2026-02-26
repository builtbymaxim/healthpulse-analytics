//
//  EditProfileView.swift
//  HealthPulse
//
//  Edit profile: name, avatar, email/password
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var displayName: String = ""
    @State private var selectedAvatar: String = "person.circle.fill"
    @State private var isSaving = false
    @State private var showingAvatarPicker = false
    @State private var showingChangeEmail = false
    @State private var showingChangePassword = false

    var body: some View {
        Form {
            // Avatar + Name
            Section {
                HStack {
                    Spacer()
                    Button {
                        showingAvatarPicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: selectedAvatar)
                                .font(.system(size: 70))
                                .foregroundStyle(.green)

                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white, .green)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            // Account
            Section("Account") {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authService.currentUser?.email ?? "")
                        .foregroundStyle(.secondary)
                }

                Button("Change Email") {
                    showingChangeEmail = true
                }

                Button("Change Password") {
                    showingChangePassword = true
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            displayName = authService.currentUser?.displayName ?? ""
            selectedAvatar = authService.currentUser?.avatarUrl ?? "person.circle.fill"
        }
        .sheet(isPresented: $showingAvatarPicker) {
            AvatarPickerView(selected: $selectedAvatar)
        }
        .sheet(isPresented: $showingChangeEmail) {
            ChangeEmailView()
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
        .loadingOverlay(isLoading: isSaving, message: "Saving...")
    }

    private func save() {
        isSaving = true
        HapticsManager.shared.medium()
        Task {
            do {
                // Update display name + avatar in one call
                try await APIService.shared.updateDisplayNameAndAvatar(
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    avatarUrl: selectedAvatar
                )
                // Reload profile to reflect changes
                await authService.loadProfile()
                HapticsManager.shared.success()
                ToastManager.shared.success("Profile updated!")
            } catch {
                HapticsManager.shared.error()
                ToastManager.shared.error("Failed to save: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }
}

// MARK: - Avatar Picker

struct AvatarPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, symbols: [String])] = [
        ("Fitness", [
            "person.circle.fill",
            "figure.run",
            "figure.walk",
            "figure.hiking",
            "figure.pool.swim",
            "figure.outdoor.cycle",
            "dumbbell.fill",
            "figure.strengthtraining.traditional",
            "figure.boxing",
            "figure.martial.arts",
            "figure.yoga",
        ]),
        ("Animals", [
            "pawprint.fill",
            "cat.fill",
            "dog.fill",
            "hare.fill",
            "tortoise.fill",
            "bird.fill",
            "fish.fill",
            "ant.fill",
            "ladybug.fill",
        ]),
        ("Power", [
            "bolt.fill",
            "flame.fill",
            "trophy.fill",
            "crown.fill",
            "shield.fill",
            "mountain.2.fill",
            "bolt.heart.fill",
        ]),
        ("Vibes", [
            "heart.fill",
            "star.fill",
            "sparkles",
            "leaf.fill",
            "sun.max.fill",
            "moon.fill",
            "brain.head.profile.fill",
            "theatermasks.fill",
            "guitar.fill",
        ]),
    ]

    private let columns = [GridItem(.adaptive(minimum: 70))]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.symbols, id: \.self) { symbol in
                                    Button {
                                        selected = symbol
                                        HapticsManager.shared.selection()
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selected == symbol ? Color.green.opacity(0.2) : Color(.tertiarySystemBackground))
                                                .frame(width: 70, height: 70)

                                            Image(systemName: symbol)
                                                .font(.system(size: 30))
                                                .foregroundStyle(selected == symbol ? .green : .primary)

                                            if selected == symbol {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.green)
                                                    .offset(x: 22, y: -22)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Change Email

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var succeeded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("New Email", text: $newEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                } footer: {
                    Text("A confirmation link will be sent to your new email address.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if succeeded {
                    Section {
                        Label("Check your new email for a confirmation link.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(isLoading || newEmail.isEmpty || currentPassword.isEmpty || succeeded)
                }
            }
            .loadingOverlay(isLoading: isLoading, message: "Updating...")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                _ = try await APIService.shared.changeEmail(newEmail: newEmail, currentPassword: currentPassword)
                succeeded = true
                HapticsManager.shared.success()
            } catch {
                errorMessage = error.localizedDescription
                HapticsManager.shared.error()
            }
            isLoading = false
        }
    }
}

// MARK: - Change Password

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var succeeded = false

    private var validationError: String? {
        if !newPassword.isEmpty && newPassword.count < 8 {
            return "Password must be at least 8 characters"
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords don't match"
        }
        return nil
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword && !succeeded
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                }

                Section {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)

                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                } footer: {
                    if let validation = validationError {
                        Text(validation)
                            .foregroundStyle(.red)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if succeeded {
                    Section {
                        Label("Password updated successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submit() }
                        .disabled(isLoading || !canSubmit)
                }
            }
            .loadingOverlay(isLoading: isLoading, message: "Updating...")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                _ = try await APIService.shared.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                succeeded = true
                HapticsManager.shared.success()
            } catch {
                errorMessage = error.localizedDescription
                HapticsManager.shared.error()
            }
            isLoading = false
        }
    }
}
