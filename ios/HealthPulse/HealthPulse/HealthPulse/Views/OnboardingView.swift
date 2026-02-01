//
//  OnboardingView.swift
//  HealthPulse
//
//  Mandatory onboarding flow for new users
//

import SwiftUI

// Note: Gender, FitnessGoal, and ActivityLevel enums are defined in NutritionModels.swift

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKit: HealthKitService

    @State private var currentStep = 0
    @State private var isAnimating = false
    @State private var isSaving = false

    // User data
    @State private var age: Int = 25
    @State private var heightCm: Double = 170
    @State private var gender: Gender = .male
    @State private var weightKg: Double = 70
    @State private var fitnessGoal: FitnessGoal = .health
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var targetWeightKg: Double = 70
    @State private var targetSleepHours: Double = 8
    @State private var caloriePreview: CalorieTargetsPreview?
    @State private var isLoadingPreview = false

    let totalSteps = 8

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .tint(.green)
                .padding(.horizontal)
                .padding(.top)

            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                physicalProfileStep.tag(1)
                weightStep.tag(2)
                goalStep.tag(3)
                activityStep.tag(4)
                caloriePreviewStep.tag(5)
                sleepStep.tag(6)
                healthKitStep.tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                        HapticsManager.shared.selection()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }

                // HealthKit step has special buttons
                if currentStep == totalSteps - 1 {
                    // Skip button for HealthKit
                    Button {
                        HapticsManager.shared.selection()
                        saveProfile()
                    } label: {
                        Text("Skip")
                            .font(.headline)
                    }
                    .frame(width: 80, height: 56)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(isSaving)

                    // Connect Health button
                    Button {
                        connectHealthAndFinish()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Connect Health")
                            }
                            .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(isSaving)
                } else {
                    // Regular continue button
                    Button {
                        handleNext()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .disabled(isSaving)
                }
            }
            .padding()
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                .animation(heartbeatAnimation, value: isAnimating)
                .onAppear {
                    isAnimating = true
                }

            VStack(spacing: 12) {
                Text("Welcome to HealthPulse")
                    .font(.title.bold())

                Text("Let's personalize your experience")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    private var physicalProfileStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Your Profile")
                    .font(.title.bold())
                Text("We'll use this to calculate your metrics")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            HStack(spacing: 16) {
                // Age Picker
                VStack(spacing: 8) {
                    Text("Age")
                        .font(.headline)

                    Picker("Age", selection: $age) {
                        ForEach(13...100, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                    .onChange(of: age) { _, _ in
                        HapticsManager.shared.selection()
                    }

                    Text("years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Height Picker
                VStack(spacing: 8) {
                    Text("Height")
                        .font(.headline)

                    Picker("Height", selection: Binding(
                        get: { Int(heightCm) },
                        set: { heightCm = Double($0) }
                    )) {
                        ForEach(100...250, id: \.self) { cm in
                            Text("\(cm)").tag(cm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                    .onChange(of: heightCm) { _, _ in
                        HapticsManager.shared.selection()
                    }

                    Text("cm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            // Gender
            VStack(alignment: .leading, spacing: 12) {
                Text("Gender")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Button {
                            gender = g
                            HapticsManager.shared.selection()
                        } label: {
                            Text(g.displayName)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(gender == g ? Color.green : Color(.secondarySystemBackground))
                                .foregroundStyle(gender == g ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var weightStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Current Weight")
                    .font(.title.bold())
                Text("You can update this anytime")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                Text("\(String(format: "%.1f", weightKg))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Weight picker with integer and decimal parts
            HStack(spacing: 0) {
                Picker("Kilograms", selection: Binding(
                    get: { Int(weightKg) },
                    set: { weightKg = Double($0) + (weightKg - floor(weightKg)) }
                )) {
                    ForEach(30...200, id: \.self) { kg in
                        Text("\(kg)").tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .clipped()

                Text(".")
                    .font(.title)
                    .foregroundStyle(.secondary)

                Picker("Decimal", selection: Binding(
                    get: { Int((weightKg - floor(weightKg)) * 10) },
                    set: { weightKg = floor(weightKg) + Double($0) / 10.0 }
                )) {
                    ForEach(0...9, id: \.self) { decimal in
                        Text("\(decimal)").tag(decimal)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
                .clipped()

                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .frame(height: 150)
            .onChange(of: weightKg) { _, _ in
                HapticsManager.shared.selection()
            }

            Spacer()
        }
    }

    private var goalStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Goal")
                    .font(.title.bold())
                Text("What do you want to achieve?")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        fitnessGoal = goal
                        // Auto-suggest target weight based on goal
                        targetWeightKg = goal.suggestedTargetWeight(currentWeight: weightKg)
                        HapticsManager.shared.selection()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: goal.icon)
                                .font(.title2)
                                .foregroundStyle(fitnessGoal == goal ? .white : goal.color)
                                .frame(width: 44, height: 44)
                                .background(fitnessGoal == goal ? goal.color : goal.color.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.displayName)
                                    .font(.headline)
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
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(fitnessGoal == goal ? Color.green : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)

            // Target weight for weight-change goals
            if fitnessGoal == .loseWeight || fitnessGoal == .buildMuscle {
                VStack(spacing: 8) {
                    HStack {
                        Text("Target Weight")
                            .font(.headline)
                        Spacer()
                        Text("Suggested: \(String(format: "%.1f", fitnessGoal.suggestedTargetWeight(currentWeight: weightKg))) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 0) {
                        Picker("Target kg", selection: Binding(
                            get: { Int(targetWeightKg) },
                            set: { targetWeightKg = Double($0) + (targetWeightKg - floor(targetWeightKg)) }
                        )) {
                            ForEach(30...200, id: \.self) { kg in
                                Text("\(kg)").tag(kg)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        .clipped()

                        Text(".")
                            .font(.title2)

                        Picker("Decimal", selection: Binding(
                            get: { Int((targetWeightKg - floor(targetWeightKg)) * 10) },
                            set: { targetWeightKg = floor(targetWeightKg) + Double($0) / 10.0 }
                        )) {
                            ForEach(0...9, id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()

                        Text("kg")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                    .onChange(of: targetWeightKg) { _, _ in
                        HapticsManager.shared.selection()
                    }

                    // Show weight change
                    let diff = targetWeightKg - weightKg
                    if abs(diff) > 0.1 {
                        Text(diff > 0 ? "+\(String(format: "%.1f", diff)) kg" : "\(String(format: "%.1f", diff)) kg")
                            .font(.subheadline.bold())
                            .foregroundStyle(diff > 0 ? .orange : .blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var activityStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Activity Level")
                    .font(.title.bold())
                Text("How active are you typically?")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        activityLevel = level
                        HapticsManager.shared.selection()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(level.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activityLevel == level ? Color.green : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var caloriePreviewStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Daily Targets")
                    .font(.title.bold())
                Text("Based on your profile and goals")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            if isLoadingPreview {
                ProgressView("Calculating...")
                    .frame(maxHeight: .infinity)
            } else if let preview = caloriePreview {
                VStack(spacing: 20) {
                    // Calorie breakdown card
                    VStack(spacing: 16) {
                        // BMR
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BMR")
                                    .font(.subheadline.bold())
                                Text("Base metabolism")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(preview.bmr))")
                                .font(.title3.bold())
                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // TDEE
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TDEE")
                                    .font(.subheadline.bold())
                                Text("With activity")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(preview.tdee))")
                                .font(.title3.bold())
                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // Target
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Target")
                                    .font(.subheadline.bold())
                                Text("For \(fitnessGoal.displayName.lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(preview.calorieTarget))")
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Macro breakdown card
                    VStack(spacing: 12) {
                        Text("Macro Targets")
                            .font(.headline)

                        HStack(spacing: 16) {
                            MacroPreviewBox(
                                name: "Protein",
                                grams: Int(preview.macros.proteinG),
                                percent: Int(preview.macros.proteinPct),
                                color: .blue
                            )
                            MacroPreviewBox(
                                name: "Carbs",
                                grams: Int(preview.macros.carbsG),
                                percent: Int(preview.macros.carbsPct),
                                color: .orange
                            )
                            MacroPreviewBox(
                                name: "Fat",
                                grams: Int(preview.macros.fatG),
                                percent: Int(preview.macros.fatPct),
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("You can adjust these in your profile settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Couldn't load calorie targets")
                        .foregroundStyle(.secondary)
                    Text("We'll calculate them once you're online")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }

            Spacer()
        }
    }

    private var sleepStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Sleep Goal")
                    .font(.title.bold())
                Text("How many hours do you want to sleep?")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 16) {
                Text("\(String(format: "%.1f", targetSleepHours))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.purple)

                Text("hours per night")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Sleep hours picker with integer and half hours
            HStack(spacing: 0) {
                Picker("Hours", selection: Binding(
                    get: { Int(targetSleepHours) },
                    set: { targetSleepHours = Double($0) + (targetSleepHours - floor(targetSleepHours)) }
                )) {
                    ForEach(5...12, id: \.self) { hours in
                        Text("\(hours)").tag(hours)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                .clipped()

                Text(":")
                    .font(.title)
                    .foregroundStyle(.secondary)

                Picker("Minutes", selection: Binding(
                    get: { Int((targetSleepHours - floor(targetSleepHours)) * 2) },
                    set: { targetSleepHours = floor(targetSleepHours) + Double($0) * 0.5 }
                )) {
                    Text("00").tag(0)
                    Text("30").tag(1)
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                .clipped()

                Text("hrs")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .frame(height: 150)
            .onChange(of: targetSleepHours) { _, _ in
                HapticsManager.shared.selection()
            }

            Spacer()
        }
    }

    private var healthKitStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Connect Health Data")
                    .font(.title.bold())
                Text("Sync with Apple Health for automatic tracking")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.pink)
                .padding()

            VStack(spacing: 12) {
                HealthKitBenefitRow(icon: "figure.run", text: "Automatic workout sync")
                HealthKitBenefitRow(icon: "heart.fill", text: "Heart rate & HRV tracking")
                HealthKitBenefitRow(icon: "moon.zzz.fill", text: "Sleep analysis")
                HealthKitBenefitRow(icon: "scalemass.fill", text: "Weight & body metrics")
            }
            .padding(.horizontal)

            Text("You can always enable this later in Settings")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var heartbeatAnimation: Animation {
        Animation
            .timingCurve(0.8, 0, 0.2, 1, duration: 0.15)
            .repeatForever(autoreverses: true)
            .delay(0.8)
    }

    private func handleNext() {
        HapticsManager.shared.medium()

        if currentStep == 4 {
            // After activity level, load calorie preview before advancing
            Task {
                await loadCaloriePreview()
                await MainActor.run {
                    withAnimation { currentStep += 1 }
                }
            }
        } else {
            withAnimation { currentStep += 1 }
        }
    }

    private func connectHealthAndFinish() {
        HapticsManager.shared.medium()
        isSaving = true

        Task {
            // Request HealthKit authorization (non-blocking)
            await healthKit.requestAuthorization()

            // Then save profile
            await MainActor.run {
                saveProfileInternal()
            }
        }
    }

    private func loadCaloriePreview() async {
        isLoadingPreview = true
        do {
            caloriePreview = try await APIService.shared.previewCalorieTargets(
                goalType: fitnessGoal,
                weightKg: weightKg
            )
        } catch {
            print("Failed to load calorie preview: \(error)")
        }
        isLoadingPreview = false
    }

    private func saveProfile() {
        isSaving = true
        saveProfileInternal()
    }

    private func saveProfileInternal() {
        Task {
            do {
                let profileData = OnboardingProfile(
                    age: age,
                    heightCm: heightCm,
                    gender: gender.rawValue,
                    weightKg: weightKg,
                    fitnessGoal: fitnessGoal.rawValue,
                    activityLevel: activityLevel.rawValue,
                    targetWeightKg: targetWeightKg,
                    targetSleepHours: targetSleepHours
                )

                try await APIService.shared.saveOnboardingProfile(profileData)

                await MainActor.run {
                    isSaving = false
                    authService.isOnboardingComplete = true
                    HapticsManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.error()
                    // Show more helpful error message
                    if let urlError = error as? URLError {
                        ToastManager.shared.error("Network error. Please try again.")
                    } else {
                        ToastManager.shared.error("Failed to save profile. Please try again.")
                    }
                    print("Onboarding save error: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct HealthKitBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)

            Spacer()

            Image(systemName: "checkmark")
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MacroPreviewBox: View {
    let name: String
    let grams: Int
    let percent: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(grams)g")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.primary)
            Text("\(percent)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Onboarding Profile Model

struct OnboardingProfile: Encodable {
    let age: Int
    let heightCm: Double
    let gender: String
    let weightKg: Double
    let fitnessGoal: String
    let activityLevel: String
    let targetWeightKg: Double
    let targetSleepHours: Double

    enum CodingKeys: String, CodingKey {
        case age
        case heightCm = "height_cm"
        case gender
        case weightKg = "weight_kg"
        case fitnessGoal = "fitness_goal"
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case targetSleepHours = "target_sleep_hours"
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
