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
    @State private var displayName: String = ""
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
    @FocusState private var nameFieldFocused: Bool

    // Training preferences
    @State private var trainingModality: TrainingModality = .gym
    @State private var selectedEquipment: Set<Equipment> = [.barbell, .dumbbells, .cableMachine]
    @State private var daysPerWeek: Int = 4
    @State private var preferredDays: Set<Int> = [1, 2, 4, 5]  // Mon, Tue, Thu, Fri
    @State private var suggestedPlan: PlanTemplatePreview?
    @State private var isLoadingPlan = false
    @State private var socialOptIn: Bool = false
    // Plan customisation during onboarding
    @State private var showPlanEditor = false
    @State private var editedPlanName: String = ""
    @State private var editedPlanDays: [Int: DraftDay]? = nil

    // Dietary profile (Phase 8C Batch 2)
    @State private var dietaryPattern: String = "omnivore"
    @State private var selectedAllergies: Set<String> = []
    @State private var mealsPerDay: Int = 3
    // Experience & motivation
    @State private var experienceLevel: String = "beginner"
    @State private var motivation: String = "health"
    @State private var bodyFatPct: Double? = nil
    @State private var showBodyFatPicker = false

    let totalSteps = 11

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .tint(.green)
                .padding(.horizontal)
                .padding(.top)

            // Content
            TabView(selection: $currentStep) {
                welcomeNameStep.tag(0)
                physicalProfileStep.tag(1)
                weightGoalStep.tag(2)
                activityStep.tag(3)
                trainingModalityStep.tag(4)
                scheduleStep.tag(5)
                planSuggestionStep.tag(6)
                sleepSocialStep.tag(7)
                dietaryProfileStep.tag(8)
                experienceStep.tag(9)
                healthKitStep.tag(10)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(MotionTokens.primary, value: currentStep)

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button {
                        withAnimation(MotionTokens.primary) { currentStep -= 1 }
                        HapticsManager.shared.selection()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressEffect())
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
                            .foregroundStyle(.primary)
                            .frame(width: 80, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressEffect())
                    .disabled(isSaving)

                    // Connect Health button
                    Button {
                        connectHealthAndFinish()
                    } label: {
                        Group {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressEffect())
                    .disabled(isSaving)
                } else {
                    // Regular continue button
                    Button {
                        handleNext()
                    } label: {
                        Group {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressEffect())
                    .disabled(isSaving)
                }
            }
            .padding()
        }
    }

    // MARK: - Steps

    private var welcomeNameStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
                .scaleEffect(isAnimating ? 1.08 : 1.0)
                .animation(heartbeatAnimation, value: isAnimating)
                .onAppear {
                    isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        nameFieldFocused = true
                    }
                }

            VStack(spacing: 8) {
                Text("Welcome to HealthPulse")
                    .font(.title.bold())

                Text("What should we call you?")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            TextField("Your name", text: $displayName)
                .font(.title2)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .focused($nameFieldFocused)
                .onSubmit { handleNext() }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)

            Spacer()

            // Sign in option for users who already have an account
            Button {
                authService.signOut()
            } label: {
                Text("Already have an account? Sign In")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            .padding(.bottom, 8)
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
                                .background(gender == g ? Color.green : AppTheme.surface2)
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

    private var weightGoalStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Weight & Goal")
                        .font(.title.bold())
                    Text("Where are you now, and where do you want to be?")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Current weight
                VStack(spacing: 8) {
                    Text("\(String(format: "%.1f", weightKg)) kg")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)

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
                    .frame(height: 120)
                    .onChange(of: weightKg) { _, _ in
                        HapticsManager.shared.selection()
                    }
                }

                Divider().padding(.horizontal)

                // Goal selection
                VStack(spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Button {
                            fitnessGoal = goal
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
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(fitnessGoal == goal ? Color.green : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
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

                        let diff = targetWeightKg - weightKg
                        if abs(diff) > 0.1 {
                            Text(diff > 0 ? "+\(String(format: "%.1f", diff)) kg" : "\(String(format: "%.1f", diff)) kg")
                                .font(.subheadline.bold())
                                .foregroundStyle(diff > 0 ? .orange : .blue)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
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
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activityLevel == level ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
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
                    .background(.ultraThinMaterial)
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
                    .background(.ultraThinMaterial)
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

    private var trainingModalityStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Where Do You Train?")
                    .font(.title.bold())
                Text("We'll suggest the right plan for you")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                ForEach(TrainingModality.allCases, id: \.self) { modality in
                    Button {
                        trainingModality = modality
                        // Set default equipment based on modality
                        if modality == .gym {
                            selectedEquipment = [.barbell, .dumbbells, .cableMachine]
                        } else if modality == .home {
                            selectedEquipment = [.dumbbells, .pullupBar]
                        } else {
                            selectedEquipment = []
                        }
                        HapticsManager.shared.selection()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: modality.icon)
                                .font(.title2)
                                .foregroundStyle(trainingModality == modality ? .white : modality.color)
                                .frame(width: 44, height: 44)
                                .background(trainingModality == modality ? modality.color : modality.color.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(modality.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(modality.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if trainingModality == modality {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(trainingModality == modality ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal)

            // Equipment selection for gym/home
            if trainingModality == .gym || trainingModality == .home {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Equipment")
                        .font(.headline)
                        .padding(.horizontal)

                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Equipment.forModality(trainingModality), id: \.self) { equipment in
                            Button {
                                if selectedEquipment.contains(equipment) {
                                    selectedEquipment.remove(equipment)
                                } else {
                                    selectedEquipment.insert(equipment)
                                }
                                HapticsManager.shared.selection()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedEquipment.contains(equipment) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedEquipment.contains(equipment) ? .green : .secondary)
                                    Text(equipment.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.surface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
    }

    private var scheduleStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Schedule")
                    .font(.title.bold())
                Text("How many days can you commit?")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Days per week
            VStack(spacing: 16) {
                Text("\(daysPerWeek)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("days per week")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(2...6, id: \.self) { days in
                        Button {
                            daysPerWeek = days
                            // Auto-select days based on count
                            updatePreferredDays(for: days)
                            HapticsManager.shared.selection()
                        } label: {
                            Text("\(days)")
                                .font(.headline)
                                .frame(width: 48, height: 48)
                                .background(daysPerWeek == days ? Color.green : AppTheme.surface2)
                                .foregroundStyle(daysPerWeek == days ? .white : .primary)
                                .clipShape(Circle())
                        }
                    }
                }
            }

            Divider()
                .padding(.horizontal)

            // Preferred days
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferred Days")
                    .font(.headline)

                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        Button {
                            if preferredDays.contains(day) {
                                preferredDays.remove(day)
                            } else if preferredDays.count < daysPerWeek {
                                preferredDays.insert(day)
                            }
                            HapticsManager.shared.selection()
                        } label: {
                            Text(dayAbbreviation(day))
                                .font(.subheadline.bold())
                                .frame(width: 44, height: 44)
                                .background(preferredDays.contains(day) ? Color.green : AppTheme.surface2)
                                .foregroundStyle(preferredDays.contains(day) ? .white : .primary)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.horizontal)

            if preferredDays.count < daysPerWeek {
                Text("Select \(daysPerWeek - preferredDays.count) more day\(daysPerWeek - preferredDays.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }

    private var planSuggestionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Training Plan")
                    .font(.title.bold())
                Text("Based on your goals and schedule")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            if isLoadingPlan {
                ProgressView("Finding the perfect plan...")
                    .frame(maxHeight: .infinity)
            } else if let plan = suggestedPlan {
                VStack(spacing: 16) {
                    // Plan card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .font(.title2.bold())
                                Text(plan.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(plan.daysPerWeek) days")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }

                        Divider()

                        // Weekly overview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Schedule")
                                .font(.subheadline.bold())

                            ForEach(plan.workouts, id: \.day) { workout in
                                HStack {
                                    Text(dayName(workout.day))
                                        .font(.subheadline)
                                        .frame(width: 60, alignment: .leading)
                                    Text(workout.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(workout.estimatedMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green, lineWidth: 2)
                    )

                    Text(editedPlanDays != nil ? "Plan customized" : "You can customize this plan anytime")
                        .font(.caption)
                        .foregroundStyle(editedPlanDays != nil ? .green : .secondary)

                    Button {
                        showPlanEditor = true
                        HapticsManager.shared.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: editedPlanDays != nil ? "pencil.circle.fill" : "pencil.circle")
                            Text(editedPlanDays != nil ? "Edit Again" : "Edit Plan")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressEffect())
                }
                .padding(.horizontal)
                .fullScreenCover(isPresented: $showPlanEditor) {
                    let initDays: [Int: DraftDay] = {
                        if let existing = editedPlanDays { return existing }
                        guard let plan = suggestedPlan else { return [:] }
                        return Dictionary(uniqueKeysWithValues: plan.workouts.map { workout in
                            (workout.day, DraftDay(dayOfWeek: workout.day, workoutName: workout.name))
                        })
                    }()
                    CustomPlanBuilderView(
                        onCapture: { name, days in
                            editedPlanName = name
                            editedPlanDays = days
                        },
                        initialPlanName: editedPlanName.isEmpty ? (suggestedPlan?.name ?? "My Plan") : editedPlanName,
                        initialDays: initDays
                    )
                }
            } else {
                // No plan available - show generic message
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("We'll help you find the right plan")
                        .font(.headline)

                    Text("Based on your \(daysPerWeek)-day schedule, we'll suggest workouts that match your \(fitnessGoal.displayName.lowercased()) goal.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxHeight: .infinity)
            }

            Spacer()
        }
    }

    private var sleepSocialStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sleep section
                VStack(spacing: 8) {
                    Text("Sleep & Social")
                        .font(.title.bold())
                    Text("How many hours do you want to sleep?")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("\(String(format: "%.1f", targetSleepHours))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)

                    Text("hours per night")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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
                .frame(height: 120)
                .onChange(of: targetSleepHours) { _, _ in
                    HapticsManager.shared.selection()
                }

                Divider().padding(.horizontal)

                // Social section
                VStack(spacing: 8) {
                    Text("Train with Friends?")
                        .font(.headline)
                    Text("Connect with training partners and challenge each other")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        socialOptIn = true
                        HapticsManager.shared.selection()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "trophy.fill")
                                .font(.title2)
                                .foregroundStyle(socialOptIn ? .white : .green)
                                .frame(width: 44, height: 44)
                                .background(socialOptIn ? Color.green : Color.green.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yes, let's compete!")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Compare PRs, streaks, and more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if socialOptIn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(socialOptIn ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                    }

                    Button {
                        socialOptIn = false
                        HapticsManager.shared.selection()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "figure.run")
                                .font(.title2)
                                .foregroundStyle(!socialOptIn ? .white : .secondary)
                                .frame(width: 44, height: 44)
                                .background(!socialOptIn ? Color.secondary : Color(.tertiarySystemBackground))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("I prefer solo training")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Focus on your own progress")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !socialOptIn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(!socialOptIn ? Color.secondary.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)

                Text("You can change this anytime in Settings")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Dietary Profile Step

    private var dietaryProfileStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Dietary Profile")
                        .font(.title.bold())
                    Text("Help us personalize your nutrition recommendations")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Diet type
                VStack(alignment: .leading, spacing: 12) {
                    Text("How do you eat?")
                        .font(.headline)

                    let dietOptions: [(String, String, String)] = [
                        ("omnivore", "Omnivore", "fork.knife"),
                        ("vegetarian", "Vegetarian", "leaf.fill"),
                        ("vegan", "Vegan", "leaf.circle.fill"),
                        ("pescatarian", "Pescatarian", "fish.fill"),
                        ("keto", "Keto / Low-Carb", "flame.fill"),
                    ]

                    ForEach(dietOptions, id: \.0) { value, label, icon in
                        Button {
                            dietaryPattern = value
                            HapticsManager.shared.selection()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(dietaryPattern == value ? .white : .green)
                                    .frame(width: 40, height: 40)
                                    .background(dietaryPattern == value ? Color.green : Color.green.opacity(0.15))
                                    .clipShape(Circle())

                                Text(label)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                if dietaryPattern == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(dietaryPattern == value ? Color.green : Color.clear, lineWidth: 2)
                            )
                        }
                        .contentShape(Rectangle())
                    }
                }

                // Allergies
                VStack(alignment: .leading, spacing: 12) {
                    Text("Any allergies or intolerances?")
                        .font(.headline)

                    let allergyOptions = ["gluten", "dairy", "nuts", "shellfish", "soy", "eggs"]

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                        ForEach(allergyOptions, id: \.self) { allergy in
                            Button {
                                if selectedAllergies.contains(allergy) {
                                    selectedAllergies.remove(allergy)
                                } else {
                                    selectedAllergies.insert(allergy)
                                }
                                HapticsManager.shared.selection()
                            } label: {
                                Text(allergy.capitalized + "-Free")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedAllergies.contains(allergy) ? Color.orange : AppTheme.surface2)
                                    .foregroundStyle(selectedAllergies.contains(allergy) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Meals per day
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Meals per day")
                            .font(.headline)
                        Spacer()
                        Text("\(mealsPerDay)")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }

                    Stepper("", value: $mealsPerDay, in: 2...5)
                        .labelsHidden()
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Experience & Motivation Step

    private var experienceStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Your Experience")
                        .font(.title.bold())
                    Text("This helps us tailor plan difficulty and goal aggressiveness")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Experience level
                VStack(alignment: .leading, spacing: 12) {
                    Text("Training experience")
                        .font(.headline)

                    let expOptions: [(String, String, String)] = [
                        ("beginner", "Beginner", "Less than 1 year"),
                        ("intermediate", "Intermediate", "1-3 years"),
                        ("advanced", "Advanced", "3+ years"),
                    ]

                    ForEach(expOptions, id: \.0) { value, label, desc in
                        Button {
                            experienceLevel = value
                            HapticsManager.shared.selection()
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if experienceLevel == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(14)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(experienceLevel == value ? Color.green : Color.clear, lineWidth: 2)
                            )
                        }
                        .contentShape(Rectangle())
                    }
                }

                // Motivation
                VStack(alignment: .leading, spacing: 12) {
                    Text("What motivates you most?")
                        .font(.headline)

                    let motivationOptions: [(String, String, String)] = [
                        ("health", "Feel healthier", "heart.fill"),
                        ("aesthetics", "Look better", "sparkles"),
                        ("performance", "Perform better in sport", "sportscourt.fill"),
                        ("event_prep", "Prepare for an event", "calendar.badge.clock"),
                        ("doctor", "Doctor recommended", "cross.case.fill"),
                    ]

                    ForEach(motivationOptions, id: \.0) { value, label, icon in
                        Button {
                            motivation = value
                            HapticsManager.shared.selection()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(motivation == value ? .white : .blue)
                                    .frame(width: 40, height: 40)
                                    .background(motivation == value ? Color.blue : Color.blue.opacity(0.15))
                                    .clipShape(Circle())

                                Text(label)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                if motivation == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(motivation == value ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .contentShape(Rectangle())
                    }
                }

                // Optional body fat %
                VStack(alignment: .leading, spacing: 8) {
                    Text("Body fat % (optional)")
                        .font(.headline)
                    Text("Enables more accurate calorie calculation")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        withAnimation(MotionTokens.form) {
                            showBodyFatPicker.toggle()
                            if showBodyFatPicker && bodyFatPct == nil {
                                bodyFatPct = 20
                            }
                        }
                        HapticsManager.shared.selection()
                    } label: {
                        HStack {
                            Text(bodyFatPct != nil ? "\(Int(bodyFatPct!))%" : "Tap to set")
                                .font(.title3.bold())
                                .foregroundStyle(bodyFatPct != nil ? .primary : .tertiary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showBodyFatPicker ? 180 : 0))
                                .animation(MotionTokens.snappy, value: showBodyFatPicker)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showBodyFatPicker {
                        HStack {
                            Picker("Body Fat %", selection: Binding(
                                get: { Int(bodyFatPct ?? 20) },
                                set: { bodyFatPct = Double($0) }
                            )) {
                                ForEach(5...50, id: \.self) { pct in
                                    Text("\(pct)%").tag(pct)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .clipped()

                            Button("Clear") {
                                withAnimation(MotionTokens.form) {
                                    bodyFatPct = nil
                                    showBodyFatPicker = false
                                }
                                HapticsManager.shared.selection()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
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
        MotionTokens.entrance.repeatForever(autoreverses: true)
    }

    private func handleNext() {
        nameFieldFocused = false
        HapticsManager.shared.medium()

        // Welcome+Name step: require non-empty name
        if currentStep == 0 && displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            return
        }

        // Schedule step: validate preferred days match days per week
        if currentStep == 5 {
            guard preferredDays.count == daysPerWeek else {
                HapticsManager.shared.error()
                return
            }
            // Load suggested plan before advancing
            Task {
                await loadSuggestedPlan()
                await MainActor.run {
                    withAnimation(MotionTokens.primary) { currentStep += 1 }
                }
            }
        } else {
            withAnimation(MotionTokens.primary) { currentStep += 1 }
        }
    }

    private func dayAbbreviation(_ day: Int) -> String {
        switch day {
        case 1: return "Mo"
        case 2: return "Tu"
        case 3: return "We"
        case 4: return "Th"
        case 5: return "Fr"
        case 6: return "Sa"
        case 7: return "Su"
        default: return ""
        }
    }

    private func dayName(_ day: Int) -> String {
        switch day {
        case 1: return "Monday"
        case 2: return "Tuesday"
        case 3: return "Wednesday"
        case 4: return "Thursday"
        case 5: return "Friday"
        case 6: return "Saturday"
        case 7: return "Sunday"
        default: return ""
        }
    }

    private func updatePreferredDays(for count: Int) {
        // Common workout splits based on days per week
        switch count {
        case 2:
            preferredDays = [1, 4]  // Mon, Thu
        case 3:
            preferredDays = [1, 3, 5]  // Mon, Wed, Fri
        case 4:
            preferredDays = [1, 2, 4, 5]  // Mon, Tue, Thu, Fri
        case 5:
            preferredDays = [1, 2, 3, 4, 5]  // Mon-Fri
        case 6:
            preferredDays = [1, 2, 3, 4, 5, 6]  // Mon-Sat
        default:
            preferredDays = [1, 3, 5]
        }
    }

    private func loadSuggestedPlan() async {
        isLoadingPlan = true

        // For now, create a mock suggested plan based on user preferences
        // In the future, this would fetch from the API based on templates
        await MainActor.run {
            suggestedPlan = suggestPlanLocally()
            isLoadingPlan = false
        }
    }

    private func suggestPlanLocally() -> PlanTemplatePreview? {
        // Suggest plan based on days per week and modality
        let sortedDays = preferredDays.sorted()

        if trainingModality == .home || trainingModality == .outdoor {
            // Home/outdoor: suggest bodyweight plan
            return PlanTemplatePreview(
                id: UUID(),
                name: "Home Bodyweight",
                description: "Build strength and muscle at home with no equipment needed.",
                daysPerWeek: min(daysPerWeek, 3),
                goalType: fitnessGoal.rawValue,
                modality: trainingModality.rawValue,
                workouts: sortedDays.prefix(3).enumerated().map { index, day in
                    let workoutNames = ["Upper Body", "Lower Body", "Full Body"]
                    return WorkoutPreview(
                        day: day,
                        name: workoutNames[index % 3],
                        estimatedMinutes: 40
                    )
                }
            )
        }

        // Gym plans based on days per week
        switch daysPerWeek {
        case 2...3:
            return PlanTemplatePreview(
                id: UUID(),
                name: "Full Body Strength",
                description: "Hit every muscle group each session with compound movements.",
                daysPerWeek: daysPerWeek,
                goalType: fitnessGoal.rawValue,
                modality: "gym",
                workouts: sortedDays.prefix(3).enumerated().map { index, day in
                    let names = ["Full Body A", "Full Body B", "Full Body C"]
                    let focus = ["Squat Focus", "Deadlift Focus", "Bench Focus"]
                    return WorkoutPreview(
                        day: day,
                        name: "\(names[index % 3]) - \(focus[index % 3])",
                        estimatedMinutes: 60
                    )
                }
            )
        case 4:
            return PlanTemplatePreview(
                id: UUID(),
                name: "Upper/Lower Split",
                description: "Balanced 4-day split alternating between upper and lower body.",
                daysPerWeek: 4,
                goalType: fitnessGoal.rawValue,
                modality: "gym",
                workouts: sortedDays.prefix(4).enumerated().map { index, day in
                    let names = ["Upper Body A", "Lower Body A", "Upper Body B", "Lower Body B"]
                    return WorkoutPreview(
                        day: day,
                        name: names[index % 4],
                        estimatedMinutes: 60
                    )
                }
            )
        case 5...6:
            return PlanTemplatePreview(
                id: UUID(),
                name: "Push Pull Legs",
                description: "High frequency split. Each muscle hit twice per week.",
                daysPerWeek: daysPerWeek,
                goalType: fitnessGoal.rawValue,
                modality: "gym",
                workouts: sortedDays.prefix(6).enumerated().map { index, day in
                    let names = ["Push A", "Pull A", "Legs A", "Push B", "Pull B", "Legs B"]
                    return WorkoutPreview(
                        day: day,
                        name: names[index % 6],
                        estimatedMinutes: 55
                    )
                }
            )
        default:
            return nil
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
            // Pass all profile values since they're not saved yet during onboarding
            caloriePreview = try await APIService.shared.previewCalorieTargets(
                goalType: fitnessGoal,
                weightKg: weightKg,
                age: age,
                heightCm: heightCm,
                gender: gender.rawValue,
                activityLevel: activityLevel.rawValue
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
                let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                let profileData = OnboardingProfile(
                    displayName: trimmedName.isEmpty ? nil : trimmedName,
                    age: age,
                    heightCm: heightCm,
                    gender: gender.rawValue,
                    weightKg: weightKg,
                    fitnessGoal: fitnessGoal.rawValue,
                    activityLevel: activityLevel.rawValue,
                    targetWeightKg: targetWeightKg,
                    targetSleepHours: targetSleepHours,
                    trainingModality: trainingModality.rawValue,
                    equipment: selectedEquipment.map { $0.rawValue },
                    daysPerWeek: daysPerWeek,
                    preferredDays: Array(preferredDays).sorted(),
                    socialOptIn: socialOptIn,
                    dietaryPattern: dietaryPattern,
                    allergies: selectedAllergies.isEmpty ? nil : Array(selectedAllergies),
                    mealsPerDay: mealsPerDay,
                    experienceLevel: experienceLevel,
                    motivation: motivation,
                    bodyFatPct: bodyFatPct
                )

                try await APIService.shared.saveOnboardingProfile(profileData)

                // If user customized the plan during onboarding, activate it now.
                // createCustomPlan marks the new plan as active, superseding the template plan
                // that was created by saveOnboardingProfile above.
                if let capturedDays = editedPlanDays {
                    let payloadDays = capturedDays.values
                        .sorted { $0.dayOfWeek < $1.dayOfWeek }
                        .map { day -> CustomPlanDayPayload in
                            let exercises = day.exercises.map { draft in
                                CustomPlanExercisePayload(
                                    id: draft.exercise.id.uuidString,
                                    name: draft.exercise.name,
                                    sets: draft.sets,
                                    reps: draft.reps.isEmpty ? nil : draft.reps,
                                    notes: draft.notes.isEmpty ? nil : draft.notes
                                )
                            }
                            return CustomPlanDayPayload(
                                dayOfWeek: day.dayOfWeek,
                                workoutName: day.workoutName,
                                focus: day.focus.isEmpty ? nil : day.focus,
                                exercises: exercises
                            )
                        }
                    let request = CreateCustomPlanRequest(
                        planName: editedPlanName.trimmingCharacters(in: .whitespaces),
                        days: payloadDays
                    )
                    _ = try await APIService.shared.createCustomPlan(request)
                }

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
        .background(.ultraThinMaterial)
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
    let displayName: String?
    let age: Int
    let heightCm: Double
    let gender: String
    let weightKg: Double
    let fitnessGoal: String
    let activityLevel: String
    let targetWeightKg: Double
    let targetSleepHours: Double
    // Training preferences
    let trainingModality: String?
    let equipment: [String]?
    let daysPerWeek: Int?
    let preferredDays: [Int]?
    // Social
    let socialOptIn: Bool?
    // Dietary profile
    let dietaryPattern: String?
    let allergies: [String]?
    let mealsPerDay: Int?
    // Experience & motivation
    let experienceLevel: String?
    let motivation: String?
    let bodyFatPct: Double?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case age
        case heightCm = "height_cm"
        case gender
        case weightKg = "weight_kg"
        case fitnessGoal = "fitness_goal"
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case targetSleepHours = "target_sleep_hours"
        case trainingModality = "training_modality"
        case equipment
        case daysPerWeek = "days_per_week"
        case preferredDays = "preferred_days"
        case socialOptIn = "social_opt_in"
        case dietaryPattern = "dietary_pattern"
        case allergies
        case mealsPerDay = "meals_per_day"
        case experienceLevel = "experience_level"
        case motivation
        case bodyFatPct = "body_fat_pct"
    }
}

// MARK: - Training Preference Enums

enum TrainingModality: String, CaseIterable {
    case gym = "gym"
    case home = "home"
    case outdoor = "outdoor"
    case mixed = "mixed"

    var displayName: String {
        switch self {
        case .gym: return "Gym"
        case .home: return "Home"
        case .outdoor: return "Outdoor"
        case .mixed: return "Mixed"
        }
    }

    var description: String {
        switch self {
        case .gym: return "Full equipment access"
        case .home: return "Bodyweight or minimal equipment"
        case .outdoor: return "Running, cycling, calisthenics"
        case .mixed: return "Combination of gym and home"
        }
    }

    var icon: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .home: return "house.fill"
        case .outdoor: return "figure.run"
        case .mixed: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .gym: return .blue
        case .home: return .orange
        case .outdoor: return .green
        case .mixed: return .purple
        }
    }
}

enum Equipment: String, CaseIterable {
    case barbell = "barbell"
    case dumbbells = "dumbbells"
    case cableMachine = "cable_machine"
    case pullupBar = "pullup_bar"
    case resistanceBands = "resistance_bands"
    case kettlebells = "kettlebells"
    case bench = "bench"
    case cardioMachines = "cardio_machines"

    var displayName: String {
        switch self {
        case .barbell: return "Barbell & Rack"
        case .dumbbells: return "Dumbbells"
        case .cableMachine: return "Cable Machine"
        case .pullupBar: return "Pull-up Bar"
        case .resistanceBands: return "Resistance Bands"
        case .kettlebells: return "Kettlebells"
        case .bench: return "Bench"
        case .cardioMachines: return "Cardio Machines"
        }
    }

    static func forModality(_ modality: TrainingModality) -> [Equipment] {
        switch modality {
        case .gym:
            return [.barbell, .dumbbells, .cableMachine, .pullupBar, .bench, .cardioMachines]
        case .home:
            return [.dumbbells, .pullupBar, .resistanceBands, .kettlebells, .bench]
        case .outdoor, .mixed:
            return [.resistanceBands, .pullupBar]
        }
    }
}

// MARK: - Plan Preview Models

struct PlanTemplatePreview {
    let id: UUID
    let name: String
    let description: String
    let daysPerWeek: Int
    let goalType: String
    let modality: String
    let workouts: [WorkoutPreview]
}

struct WorkoutPreview {
    let day: Int
    let name: String
    let estimatedMinutes: Int
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
