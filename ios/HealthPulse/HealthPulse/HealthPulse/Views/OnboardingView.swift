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

    // Training preferences
    @State private var trainingModality: TrainingModality = .gym
    @State private var selectedEquipment: Set<Equipment> = [.barbell, .dumbbells, .cableMachine]
    @State private var daysPerWeek: Int = 4
    @State private var preferredDays: Set<Int> = [1, 2, 4, 5]  // Mon, Tue, Thu, Fri
    @State private var suggestedPlan: PlanTemplatePreview?
    @State private var isLoadingPlan = false
    @State private var socialOptIn: Bool = false

    let totalSteps = 13

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
                nameStep.tag(1)
                physicalProfileStep.tag(2)
                weightStep.tag(3)
                goalStep.tag(4)
                activityStep.tag(5)
                caloriePreviewStep.tag(6)
                trainingModalityStep.tag(7)
                scheduleStep.tag(8)
                planSuggestionStep.tag(9)
                sleepStep.tag(10)
                socialOptInStep.tag(11)
                healthKitStep.tag(12)
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

            // Sign in option for users who already have an account
            Button {
                // Sign out current account and return to login
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

    private var nameStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("What should we call you?")
                    .font(.title.bold())

                Text("This is how we'll greet you in the app")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Your name", text: $displayName)
                .font(.title2)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)

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
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(trainingModality == modality ? Color.green : Color.clear, lineWidth: 2)
                        )
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
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                .background(daysPerWeek == days ? Color.green : Color(.secondarySystemBackground))
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
                                .background(preferredDays.contains(day) ? Color.green : Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green, lineWidth: 2)
                    )

                    Text("You can customize this plan anytime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
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

    private var socialOptInStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Train with Friends?")
                    .font(.title.bold())
                Text("Connect with training partners and challenge each other")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .padding()

            VStack(spacing: 12) {
                // Yes option
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
                            Text("Compare PRs, streaks, and more with friends")
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(socialOptIn ? Color.green : Color.clear, lineWidth: 2)
                    )
                }

                // No option
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(!socialOptIn ? Color.secondary.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal)

            Text("You can change this anytime in Settings")
                .font(.caption)
                .foregroundStyle(.tertiary)

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

        // Name step: require non-empty name
        if currentStep == 1 && displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            return
        }

        if currentStep == 5 {
            // After activity level, load calorie preview before advancing
            Task {
                await loadCaloriePreview()
                await MainActor.run {
                    withAnimation { currentStep += 1 }
                }
            }
        } else if currentStep == 8 {
            // After schedule step, load suggested plan
            Task {
                await loadSuggestedPlan()
                await MainActor.run {
                    withAnimation { currentStep += 1 }
                }
            }
        } else {
            withAnimation { currentStep += 1 }
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
                    socialOptIn: socialOptIn
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
