//
//  ProfileView.swift
//  HealthPulse
//
//  User profile and settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading) {
                            Text(authService.currentUser?.displayName ?? "User")
                                .font(.headline)

                            Text(authService.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Health Kit section
                Section("Health Data") {
                    HStack {
                        Label("Apple Health", systemImage: "heart.fill")
                            .foregroundStyle(.red)

                        Spacer()

                        if healthKitService.isAuthorized {
                            Text("Connected")
                                .foregroundStyle(.green)
                        } else {
                            Button("Connect") {
                                Task {
                                    await healthKitService.requestAuthorization()
                                }
                            }
                        }
                    }

                    NavigationLink {
                        DataSourcesView()
                    } label: {
                        Label("Data Sources", systemImage: "link")
                    }
                }

                // Settings section
                Section("Settings") {
                    NavigationLink {
                        BaselineSettingsView()
                    } label: {
                        Label("Baseline Settings", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        UnitsSettingsView()
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                }

                // Support section
                Section("Support") {
                    Link(destination: URL(string: "https://healthpulse.app/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://healthpulse.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                // Logout section
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Sub Views

struct DataSourcesView: View {
    var body: some View {
        List {
            Section("Connected") {
                DataSourceRow(name: "Apple Health", icon: "heart.fill", color: .red, connected: true)
            }

            Section("Available") {
                DataSourceRow(name: "Strava", icon: "figure.outdoor.cycle", color: .orange, connected: false)
                DataSourceRow(name: "Garmin", icon: "applewatch", color: .blue, connected: false)
                DataSourceRow(name: "Oura", icon: "circle.circle", color: .gray, connected: false)
                DataSourceRow(name: "Whoop", icon: "waveform.path.ecg", color: .green, connected: false)
            }
        }
        .navigationTitle("Data Sources")
    }
}

struct DataSourceRow: View {
    let name: String
    let icon: String
    let color: Color
    let connected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 30)

            Text(name)

            Spacer()

            if connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Connect") {
                    // TODO: Implement OAuth flow
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct BaselineSettingsView: View {
    @State private var hrvBaseline: Double = 50
    @State private var rhrBaseline: Double = 60
    @State private var targetSleep: Double = 8
    @State private var stepGoal: Double = 10000

    var body: some View {
        Form {
            Section("Heart Rate") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("HRV Baseline")
                        Spacer()
                        Text("\(Int(hrvBaseline)) ms")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $hrvBaseline, in: 20...100, step: 1)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Resting HR Baseline")
                        Spacer()
                        Text("\(Int(rhrBaseline)) bpm")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $rhrBaseline, in: 40...100, step: 1)
                }
            }

            Section("Goals") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Target Sleep")
                        Spacer()
                        Text("\(targetSleep, specifier: "%.1f") hours")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $targetSleep, in: 5...10, step: 0.5)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Daily Step Goal")
                        Spacer()
                        Text("\(Int(stepGoal).formatted())")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $stepGoal, in: 5000...20000, step: 1000)
                }
            }
        }
        .navigationTitle("Baseline Settings")
    }
}

struct NotificationSettingsView: View {
    @State private var dailyReminder = true
    @State private var weeklySummary = true
    @State private var achievements = true
    @State private var insights = true

    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Daily Check-in Reminder", isOn: $dailyReminder)
                Toggle("Weekly Summary", isOn: $weeklySummary)
            }

            Section("Activity") {
                Toggle("Achievement Alerts", isOn: $achievements)
                Toggle("New Insights", isOn: $insights)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct UnitsSettingsView: View {
    @State private var useMetric = true

    var body: some View {
        Form {
            Section {
                Picker("Unit System", selection: $useMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }
            } footer: {
                Text(useMetric ? "Weight in kg, distance in km" : "Weight in lbs, distance in miles")
            }
        }
        .navigationTitle("Units")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("HealthPulse")
                .font(.largeTitle.bold())

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("Your personal fitness and wellness companion. Track your health, discover insights, and optimize your performance.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 60)
        .navigationTitle("About")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
