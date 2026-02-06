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
                        ProfileAndGoalsView()
                    } label: {
                        Label("Profile & Goals", systemImage: "person.text.rectangle")
                    }

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
            .navigationBarTitleDisplayMode(.inline)
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
    @State private var isSaving = false
    @State private var isLoading = true

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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                }
                .disabled(isSaving)
            }
        }
        .task {
            await loadSettings()
        }
        .loadingOverlay(isLoading: isSaving, message: "Saving...")
    }

    private func loadSettings() async {
        isLoading = true
        do {
            let user = try await APIService.shared.getProfile()
            if let settings = user.settings {
                if let hrv = settings.hrvBaseline { hrvBaseline = hrv }
                if let rhr = settings.rhrBaseline { rhrBaseline = rhr }
                if let sleep = settings.targetSleepHours { targetSleep = sleep }
                if let steps = settings.dailyStepGoal { stepGoal = Double(steps) }
            }
        } catch {
            print("Failed to load settings: \(error)")
        }
        isLoading = false
    }

    private func saveSettings() {
        isSaving = true
        HapticsManager.shared.medium()

        Task {
            do {
                try await APIService.shared.updateUserSettings(
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline,
                    targetSleepHours: targetSleep,
                    dailyStepGoal: stepGoal
                )
                HapticsManager.shared.success()
                ToastManager.shared.success("Settings saved!")
            } catch {
                HapticsManager.shared.error()
                ToastManager.shared.error("Failed to save: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        Form {
            if !notificationService.isAuthorized {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Notifications are disabled. Enable them in Settings.")
                            .font(.subheadline)
                    }
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section {
                Toggle("Meal Reminders", isOn: $notificationService.mealRemindersEnabled)

                if notificationService.mealRemindersEnabled {
                    DatePicker("Breakfast", selection: $notificationService.breakfastTime, displayedComponents: .hourAndMinute)
                    DatePicker("Lunch", selection: $notificationService.lunchTime, displayedComponents: .hourAndMinute)
                    DatePicker("Dinner", selection: $notificationService.dinnerTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Nutrition")
            } footer: {
                if notificationService.mealRemindersEnabled {
                    Text("Get reminded to log each meal at the times you choose.")
                }
            }

            Section("Workouts") {
                Toggle("Workout Day Reminder (8 AM)", isOn: $notificationService.workoutReminderEnabled)
            }

            Section("Reviews") {
                Toggle("Weekly Review (Sun 6 PM)", isOn: $notificationService.weeklyReviewEnabled)
                Toggle("Monthly Review (1st, 10 AM)", isOn: $notificationService.monthlyReviewEnabled)
            }
        }
        .navigationTitle("Notifications")
        .task {
            await notificationService.checkAuthorizationStatus()
        }
        .onDisappear {
            notificationService.savePreferences()
            Task {
                await notificationService.scheduleAllNotifications()
            }
        }
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

struct MacroTargetRow: View {
    let name: String
    let grams: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(grams)g")
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile & Goals View (Unified)

struct ProfileAndGoalsView: View {
    // Profile data
    @State private var age: Int = 25
    @State private var heightCm: Int = 170
    @State private var weightKg: Int = 70
    @State private var weightDecimal: Int = 0  // 0-9 for decimal part
    @State private var gender: Gender = .male
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var fitnessGoal: FitnessGoal = .health

    // Calculated targets
    @State private var caloriePreview: CalorieTargetsPreview?
    @State private var useCustomCalories: Bool = false
    @State private var customCalories: Double = 2000

    // UI State
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isCalculating = false
    @State private var needsRecalculation = true

    private var currentWeight: Double {
        Double(weightKg) + Double(weightDecimal) / 10.0
    }

    var body: some View {
        Form {
            // Physical Profile Section with Wheel Pickers
            Section {
                // Age Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("Age", selection: $age) {
                            ForEach(13...100, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                        .onChange(of: age) { _, _ in
                            HapticsManager.shared.selection()
                            needsRecalculation = true
                        }

                        Text("years")
                            .foregroundStyle(.secondary)
                    }
                }

                // Height Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("Height", selection: $heightCm) {
                            ForEach(100...250, id: \.self) { cm in
                                Text("\(cm)").tag(cm)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                        .onChange(of: heightCm) { _, _ in
                            HapticsManager.shared.selection()
                            needsRecalculation = true
                        }

                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }

                // Weight Picker (integer + decimal)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        Picker("Weight", selection: $weightKg) {
                            ForEach(30...200, id: \.self) { kg in
                                Text("\(kg)").tag(kg)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()
                        .onChange(of: weightKg) { _, _ in
                            HapticsManager.shared.selection()
                            needsRecalculation = true
                        }

                        Text(".")
                            .font(.title2)

                        Picker("Decimal", selection: $weightDecimal) {
                            ForEach(0...9, id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()
                        .onChange(of: weightDecimal) { _, _ in
                            HapticsManager.shared.selection()
                            needsRecalculation = true
                        }

                        Text("kg")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                }
            } header: {
                Text("Your Body")
            }

            // Gender & Activity
            Section("Profile") {
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .onChange(of: gender) { _, _ in
                    HapticsManager.shared.selection()
                    needsRecalculation = true
                }

                Picker("Activity Level", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(level)
                    }
                }
                .onChange(of: activityLevel) { _, _ in
                    HapticsManager.shared.selection()
                    needsRecalculation = true
                }
            }

            // Fitness Goal
            Section("Fitness Goal") {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        fitnessGoal = goal
                        HapticsManager.shared.selection()
                        needsRecalculation = true
                    } label: {
                        HStack {
                            Image(systemName: goal.icon)
                                .foregroundStyle(goal.color)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(goal.displayName)
                                    .foregroundStyle(.primary)
                                Text(goal.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if fitnessGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            // Calculated Targets Section
            Section {
                if isCalculating {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if let preview = caloriePreview {
                    // BMR/TDEE/Target display
                    VStack(spacing: 16) {
                        HStack {
                            TargetMetricView(title: "BMR", value: Int(preview.bmr), subtitle: "base")
                            TargetMetricView(title: "TDEE", value: Int(preview.tdee), subtitle: "active")
                            TargetMetricView(title: "Target", value: Int(preview.calorieTarget), subtitle: "daily", highlight: true)
                        }

                        Divider()

                        // Macros
                        HStack {
                            MacroTargetRow(name: "Protein", grams: Int(preview.macros.proteinG), color: .blue)
                            MacroTargetRow(name: "Carbs", grams: Int(preview.macros.carbsG), color: .orange)
                            MacroTargetRow(name: "Fat", grams: Int(preview.macros.fatG), color: .purple)
                        }
                    }
                    .padding(.vertical, 8)

                    // Custom override option
                    Toggle("Customize calorie target", isOn: $useCustomCalories)

                    if useCustomCalories {
                        HStack {
                            Text("Daily calories")
                            Spacer()
                            TextField("Calories", value: $customCalories, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("kcal")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if needsRecalculation {
                    Button {
                        Task { await calculateTargets() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Calculate Targets")
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Text("Complete your profile to see calculated targets")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } header: {
                Text("Your Daily Targets")
            } footer: {
                if caloriePreview != nil && !useCustomCalories {
                    Text("Based on Mifflin-St Jeor equation. Adjust your profile to recalculate.")
                }
            }
        }
        .navigationTitle("Profile & Goals")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveAll()
                }
                .disabled(isSaving || isCalculating)
            }
        }
        .task {
            await loadProfile()
            if needsRecalculation {
                await calculateTargets()
            }
        }
        .onChange(of: needsRecalculation) { _, needs in
            if needs {
                Task { await calculateTargets() }
            }
        }
        .loadingOverlay(isLoading: isSaving, message: "Saving...")
    }

    private func loadProfile() async {
        isLoading = true
        do {
            let user = try await APIService.shared.getProfile()
            if let userAge = user.age { age = userAge }
            if let userHeight = user.heightCm { heightCm = Int(userHeight) }
            if let userGender = user.gender {
                gender = Gender(rawValue: userGender) ?? .male
            }
            if let userActivity = user.activityLevel {
                activityLevel = ActivityLevel(rawValue: userActivity) ?? .moderate
            }
            if let userGoal = user.fitnessGoal {
                fitnessGoal = FitnessGoal(rawValue: userGoal) ?? .health
            }

            // Load latest weight
            if let latestWeight = try? await APIService.shared.getLatestWeight() {
                weightKg = Int(latestWeight)
                weightDecimal = Int((latestWeight - Double(Int(latestWeight))) * 10)
            }

            // Load existing nutrition goal
            if let goal = try? await APIService.shared.getNutritionGoal() {
                if goal.customCalorieTarget != nil {
                    useCustomCalories = true
                    customCalories = goal.effectiveCalorieTarget
                }
            }
        } catch {
            print("Failed to load profile: \(error)")
        }
        isLoading = false
    }

    private func calculateTargets() async {
        isCalculating = true
        needsRecalculation = false

        do {
            // Pass all current profile values for real-time calculation
            caloriePreview = try await APIService.shared.previewCalorieTargets(
                goalType: fitnessGoal,
                weightKg: currentWeight,
                age: age,
                heightCm: Double(heightCm),
                gender: gender.rawValue,
                activityLevel: activityLevel.rawValue
            )
            if !useCustomCalories, let preview = caloriePreview {
                customCalories = preview.calorieTarget
            }
        } catch {
            print("Failed to calculate targets: \(error)")
            // Don't show error to user, just keep previous values
        }

        isCalculating = false
    }

    private func saveAll() {
        isSaving = true
        HapticsManager.shared.medium()

        Task {
            do {
                // 1. Save profile data
                try await APIService.shared.updateUserProfile(
                    age: age,
                    heightCm: Double(heightCm),
                    gender: gender.rawValue,
                    activityLevel: activityLevel.rawValue,
                    fitnessGoal: fitnessGoal.rawValue
                )

                // 2. Log weight
                try await APIService.shared.logWeight(currentWeight)

                // 3. Save nutrition goal
                let goal = NutritionGoalCreate(
                    goalType: fitnessGoal,
                    customCalorieTarget: useCustomCalories ? customCalories : nil,
                    customProteinTargetG: nil,
                    customCarbsTargetG: nil,
                    customFatTargetG: nil,
                    adjustForActivity: true
                )
                _ = try await APIService.shared.setNutritionGoal(goal)

                HapticsManager.shared.success()
                ToastManager.shared.success("Profile & goals saved!")
            } catch {
                HapticsManager.shared.error()
                ToastManager.shared.error("Failed to save: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }
}

// Helper view for displaying target metrics
struct TargetMetricView: View {
    let title: String
    let value: Int
    let subtitle: String
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(highlight ? .green : .primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
        .environmentObject(NotificationService.shared)
}
