//
//  TodayView.swift
//  HealthPulse
//
//  Main dashboard view - redesigned for actionable insights
//

import SwiftUI
import Combine

struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var tabRouter: TabRouter
    @State private var showTrainingPlanSetup = false
    @State private var showWorkoutExecution = false
    @State private var showPRCelebration = false
    @State private var achievedPRs: [PRInfo] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Greeting — always visible at top
                    Text(viewModel.personalizedGreeting)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // 2. Readiness Header (narrative mode)
                    if !viewModel.readinessNarrative.isEmpty {
                        ReadinessHeaderView(
                            readinessScore: viewModel.readinessScore,
                            greetingContext: viewModel.greetingContext,
                            narrative: viewModel.readinessNarrative
                        )
                        .padding(.horizontal)
                    }

                    // 3. Commitment Strip (NOW / NEXT / TONIGHT) — tappable
                    if !viewModel.commitments.isEmpty {
                        CommitmentStripView(commitments: viewModel.commitments) { route in
                            navigateToRoute(route)
                        }
                        .padding(.horizontal)
                    }

                    // 4. Daily Actions — for ALL users
                    if viewModel.isNewUser {
                        // New users: onboarding checklist
                        WelcomeChecklistCard(
                            displayName: nil, // greeting is now standalone above
                            hasLoggedWorkout: viewModel.hasLoggedWorkout,
                            hasLoggedMeal: viewModel.hasLoggedMeal,
                            hasLoggedSleep: viewModel.hasLoggedSleep,
                            hasSetupTrainingPlan: viewModel.hasSetupTrainingPlan,
                            onWorkoutTap: { tabRouter.navigateTo(.workout) },
                            onMealTap: { tabRouter.navigateTo(.nutrition) },
                            onSleepTap: { tabRouter.navigateTo(.sleep) },
                            onTrainingPlanTap: { showTrainingPlanSetup = true }
                        )
                        .padding(.horizontal)
                    } else if !viewModel.dailyActions.isEmpty {
                        // Established users: daily actions from backend
                        DailyActionsCard(actions: viewModel.dailyActions) { route in
                            navigateToRoute(route)
                        }
                        .padding(.horizontal)
                    }

                    // 5. Dynamic Card Stack (narrative mode) or static fallback
                    if !viewModel.cardPriorityOrder.isEmpty {
                        ForEach(viewModel.cardPriorityOrder) { card in
                            DashboardCardRouter(cardType: card.cardType, viewModel: viewModel)
                                .padding(.horizontal)
                        }

                        // Filtered recommendations (no duplication with commitments)
                        if !viewModel.isNewUser && !viewModel.filteredRecommendations.isEmpty {
                            SmartRecommendationsSection(recommendations: viewModel.filteredRecommendations)
                                .padding(.horizontal)
                        }
                    } else {
                        staticCardStack
                    }

                    // 6. Quick Stats Row (always last)
                    HStack(spacing: 12) {
                        QuickStatCard(
                            icon: "figure.walk",
                            value: "\(healthKitService.todaySteps.formatted())",
                            label: "Steps",
                            color: .green
                        )

                        if let sleep = healthKitService.lastSleepHours {
                            QuickStatCard(
                                icon: "moon.zzz.fill",
                                value: String(format: "%.1fh", sleep),
                                label: "Sleep",
                                color: .purple
                            )
                            .onTapGesture {
                                tabRouter.navigateTo(.sleep)
                                HapticsManager.shared.light()
                            }
                        }

                        if let hr = healthKitService.restingHeartRate {
                            QuickStatCard(
                                icon: "heart.fill",
                                value: "\(Int(hr))",
                                label: "RHR",
                                color: .red
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Fallback: Compact Recovery & Readiness
                    if !viewModel.isNewUser && viewModel.enhancedRecovery == nil && viewModel.readinessNarrative.isEmpty {
                        HStack(spacing: 12) {
                            CompactScoreCard(
                                title: "Recovery",
                                score: viewModel.recoveryScore,
                                status: viewModel.recoveryStatus,
                                color: statusColor(viewModel.recoveryStatus)
                            )

                            CompactScoreCard(
                                title: "Readiness",
                                score: viewModel.readinessScore,
                                status: viewModel.recommendedIntensity,
                                color: .blue
                            )
                            .onTapGesture {
                                tabRouter.navigateTo(.workout)
                                HapticsManager.shared.light()
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
                await healthKitService.refreshTodayData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showTrainingPlanSetup) {
                TrainingPlanView()
            }
            .fullScreenCover(isPresented: $showWorkoutExecution) {
                if let workout = viewModel.todaysWorkout {
                    WorkoutExecutionView(workout: workout, planId: nil) { prs in
                        if !prs.isEmpty {
                            achievedPRs = prs
                            showPRCelebration = true
                        }
                        Task {
                            await viewModel.loadData()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPRCelebration) {
                PRCelebrationView(prs: achievedPRs) {
                    showPRCelebration = false
                    achievedPRs = []
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // Static card layout used when narrative endpoint is unavailable
    @ViewBuilder
    private var staticCardStack: some View {
        // Today's Workout Card
        if let todaysWorkout = viewModel.todaysWorkout {
            TodayWorkoutCard(
                workout: todaysWorkout,
                onTap: {
                    if todaysWorkout.isRestDay {
                        tabRouter.navigateTo(.workout)
                    } else {
                        showWorkoutExecution = true
                    }
                }
            )
            .padding(.horizontal)
        }

        // Smart Recommendations (filtered to avoid duplication with commitments)
        if !viewModel.isNewUser && !viewModel.filteredRecommendations.isEmpty {
            SmartRecommendationsSection(recommendations: viewModel.filteredRecommendations)
                .padding(.horizontal)
        }

        // Today's Nutrition Progress
        NutritionProgressCard(
            calories: viewModel.todayCalories,
            calorieGoal: viewModel.calorieGoal,
            protein: viewModel.todayProtein,
            proteinGoal: viewModel.proteinGoal,
            carbs: viewModel.todayCarbs,
            carbsGoal: viewModel.carbsGoal,
            fat: viewModel.todayFat,
            fatGoal: viewModel.fatGoal
        )
        .onTapGesture {
            tabRouter.navigateTo(.nutrition)
            HapticsManager.shared.light()
        }
        .padding(.horizontal)

        // Weekly Summary
        if !viewModel.isNewUser, let summary = viewModel.weeklySummary {
            WeeklySummaryCard(summary: summary)
                .padding(.horizontal)
        }

        // Workout Streak
        WorkoutStreakCard(
            streakDays: viewModel.workoutStreak,
            lastWorkoutDate: viewModel.lastWorkoutDate
        )
        .onTapGesture {
            tabRouter.navigateTo(.workout)
            HapticsManager.shared.light()
        }
        .padding(.horizontal)

        // Last Workout Performance
        if let lastWorkout = viewModel.lastWorkout {
            LastWorkoutCard(
                workout: lastWorkout,
                improvement: viewModel.lastWorkoutImprovement
            )
            .onTapGesture {
                tabRouter.navigateTo(.workout)
                HapticsManager.shared.light()
            }
            .padding(.horizontal)
        }

        // Nutrition Adherence
        if viewModel.hasNutritionHistory {
            NutritionAdherenceCard(
                weeklyData: viewModel.weeklyNutritionData,
                adherenceScore: viewModel.weeklyAdherenceScore
            )
            .onTapGesture {
                tabRouter.navigateTo(.nutrition)
                HapticsManager.shared.light()
            }
            .padding(.horizontal)
        }

        // Sleep Pattern
        if viewModel.hasSleepData {
            SleepPatternCard(
                avgHours: viewModel.avgSleepHours,
                consistencyScore: viewModel.sleepConsistencyScore,
                trend: viewModel.sleepTrend
            )
            .onTapGesture {
                tabRouter.navigateTo(.sleep)
                HapticsManager.shared.light()
            }
            .padding(.horizontal)
        }

        // Enhanced Recovery
        if !viewModel.isNewUser, let recovery = viewModel.enhancedRecovery {
            EnhancedRecoveryCard(recovery: recovery)
                .padding(.horizontal)
        }

        // Progress Section
        if !viewModel.isNewUser, let progress = viewModel.progressSummary {
            ProgressDashboardSection(progress: progress)
                .padding(.horizontal)
        }
    }

    private func navigateToRoute(_ route: String?) {
        guard let route else { return }
        HapticsManager.shared.light()
        switch route {
        case "workout":
            tabRouter.navigateTo(.workout)
        case "nutrition":
            tabRouter.navigateTo(.nutrition)
        case "sleep":
            tabRouter.navigateTo(.sleep)
        case "social":
            tabRouter.navigateTo(.social)
        default:
            break
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "recovered": return .green
        case "moderate": return .orange
        case "fatigued": return .red
        default: return .gray
        }
    }
}

// MARK: - Welcome Checklist Card

struct WelcomeChecklistCard: View {
    let displayName: String?
    let hasLoggedWorkout: Bool
    let hasLoggedMeal: Bool
    let hasLoggedSleep: Bool
    let hasSetupTrainingPlan: Bool
    let onWorkoutTap: () -> Void
    let onMealTap: () -> Void
    let onSleepTap: () -> Void
    let onTrainingPlanTap: () -> Void

    private var completedCount: Int {
        [hasLoggedWorkout, hasLoggedMeal, hasLoggedSleep, hasSetupTrainingPlan].filter { $0 }.count
    }

    private var personalizedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }
        if let name = displayName, !name.isEmpty {
            return "\(timeGreeting), \(name)!"
        }
        return "\(timeGreeting)!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Getting Started")
                        .font(.headline)
                    Text("Let's build your routine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedCount)/4")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.15))
                    .foregroundStyle(AppTheme.primary)
                    .clipShape(Capsule())
            }

            // Checklist items
            VStack(spacing: 12) {
                ChecklistItem(
                    isCompleted: hasLoggedWorkout,
                    title: "Complete your first workout",
                    icon: "dumbbell.fill",
                    action: onWorkoutTap
                )

                ChecklistItem(
                    isCompleted: hasLoggedMeal,
                    title: "Log today's meals",
                    icon: "fork.knife",
                    action: onMealTap
                )

                ChecklistItem(
                    isCompleted: hasLoggedSleep,
                    title: "Track your sleep",
                    icon: "moon.zzz.fill",
                    action: onSleepTap
                )

                ChecklistItem(
                    isCompleted: hasSetupTrainingPlan,
                    title: "Set up a training plan",
                    icon: "calendar.badge.clock",
                    action: onTrainingPlanTap
                )
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct ChecklistItem: View {
    let isCompleted: Bool
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isCompleted {
                HapticsManager.shared.light()
                action()
            }
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)

                // Icon
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? .secondary : AppTheme.primary)
                    .frame(width: 24)

                // Title
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary)

                Spacer()

                if !isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}

// MARK: - Today's Workout Card

struct TodayWorkoutCard: View {
    let workout: TodayWorkoutResponse
    let onTap: () -> Void

    private var dayName: String {
        let days = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return workout.dayOfWeek >= 1 && workout.dayOfWeek <= 7 ? days[workout.dayOfWeek] : ""
    }

    var body: some View {
        Button(action: {
            HapticsManager.shared.light()
            onTap()
        }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeaderLabel(text: "Today's Workout")
                            if let planName = workout.planName {
                                Text(planName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(dayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    if workout.isRestDay {
                        // Rest day view
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "bed.double.fill")
                                    .font(.title2)
                                    .foregroundStyle(.purple)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rest Day")
                                    .font(.title3.bold())

                                Text("Recovery is part of the plan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    } else {
                        // Workout day view
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "dumbbell.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.workoutName ?? "Workout")
                                    .font(.title3.bold())

                                HStack(spacing: 12) {
                                    if let focus = workout.workoutFocus {
                                        Label(focus, systemImage: "target")
                                    }
                                    if let minutes = workout.estimatedMinutes {
                                        Label("\(minutes) min", systemImage: "clock")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        // Exercise preview (show first 3)
                        if let exercises = workout.exercises, !exercises.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(exercises.prefix(3)) { exercise in
                                    HStack {
                                        Circle()
                                            .fill(AppTheme.primary.opacity(0.5))
                                            .frame(width: 6, height: 6)
                                        Text(exercise.name)
                                            .font(.caption)
                                        if let sets = exercise.sets, let reps = exercise.reps {
                                            Spacer()
                                            Text("\(sets)×\(reps)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                if exercises.count > 3 {
                                    Text("+\(exercises.count - 3) more exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 14)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .elevatedShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nutrition Progress Card

struct NutritionProgressCard: View {
    let calories: Double
    let calorieGoal: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double

    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(calories / calorieGoal, 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                SectionHeaderLabel(text: "Today's Nutrition")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Main calorie ring
            HStack(spacing: 24) {
                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(AppTheme.primary.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: calorieProgress)

                    VStack(spacing: 2) {
                        Text("\(Int(calories))")
                            .font(.system(size: 28, weight: .bold))
                            .contentTransition(.numericText())

                        Text("/ \(Int(calorieGoal))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 120, height: 120)

                // Macro bars
                VStack(spacing: 12) {
                    MacroBar(name: "Protein", current: protein, goal: proteinGoal, color: .blue)
                    MacroBar(name: "Carbs", current: carbs, goal: carbsGoal, color: .orange)
                    MacroBar(name: "Fat", current: fat, goal: fatGoal, color: .purple)
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct MacroBar: View {
    let name: String
    let current: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current))g / \(Int(goal))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Workout Streak Card

struct WorkoutStreakCard: View {
    let streakDays: Int
    let lastWorkoutDate: Date?

    var body: some View {
        HStack(spacing: 16) {
            // Flame icon
            ZStack {
                Circle()
                    .fill(streakDays > 0 ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: streakDays > 0 ? "flame.fill" : "flame")
                    .font(.title)
                    .foregroundStyle(streakDays > 0 ? .orange : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                if streakDays > 0 {
                    Text("\(streakDays) Day Streak")
                        .font(.headline)

                    Text("Keep it going!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Start Your Streak")
                        .font(.headline)

                    Text("Log a workout today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Last Workout Card

struct LastWorkoutCard: View {
    let workout: WorkoutSummary
    let improvement: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeaderLabel(text: "Last Workout")
                Spacer()
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                // Workout icon
                Image(systemName: workout.icon)
                    .font(.title)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.subheadline.bold())

                    HStack(spacing: 12) {
                        Label("\(workout.duration) min", systemImage: "clock")
                        if let calories = workout.calories {
                            Label("\(Int(calories)) kcal", systemImage: "flame")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Improvement badge
                if let improvement = improvement {
                    Text(improvement)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.15))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }
}

// MARK: - Compact Score Card

struct CompactScoreCard: View {
    let title: String
    let score: Double
    let status: String?
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(score))")
                    .font(.system(size: 14, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let status = status {
                    Text(status.capitalized)
                        .font(.subheadline.bold())
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }
}

// MARK: - Nutrition Adherence Card

struct NutritionAdherenceCard: View {
    let weeklyData: [DayAdherence]
    let adherenceScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeaderLabel(text: "Eating Habits")
                Spacer()
                Text("\(adherenceScore)% this week")
                    .font(.caption)
                    .contentTransition(.numericText())
                    .foregroundStyle(adherenceScore >= 80 ? .green : (adherenceScore >= 60 ? .orange : .secondary))
            }

            // 7-day mini chart
            HStack(spacing: 4) {
                ForEach(weeklyData.suffix(7), id: \.day) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.isOnTarget ? AppTheme.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 40 * (day.progress > 0 ? min(day.progress, 1.2) : 0.1))

                        Text(day.dayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60)

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 8, height: 8)
                    Text("On target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text("Off target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct DayAdherence: Identifiable {
    let id = UUID()
    let day: Date
    let progress: Double  // 0-1+ representing % of goal
    let isOnTarget: Bool  // 80-120% of goal

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: day).prefix(1))
    }
}

// MARK: - Sleep Pattern Card

struct SleepPatternCard: View {
    let avgHours: Double
    let consistencyScore: Int
    let trend: TrendDirection

    var body: some View {
        HStack(spacing: 16) {
            // Sleep icon with background
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1fh avg sleep", avgHours))
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: trend.icon)
                        .font(.caption)
                    Text("\(consistencyScore)% consistent")
                        .font(.caption)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(trend.color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

enum TrendDirection {
    case up, down, stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .secondary
        }
    }
}

// MARK: - Models

struct WorkoutSummary {
    let name: String
    let icon: String
    let date: Date
    let duration: Int
    let calories: Double?
}

// MARK: - View Model

@MainActor
class TodayViewModel: ObservableObject {
    // New user tracking
    @Published var displayName: String?
    @Published var isNewUser: Bool = true
    @Published var hasLoggedWorkout: Bool = false
    @Published var hasLoggedMeal: Bool = false
    @Published var hasLoggedSleep: Bool = false
    @Published var hasSetupTrainingPlan: Bool = false

    // Today's workout from training plan
    @Published var todaysWorkout: TodayWorkoutResponse?

    // Data availability flags
    @Published var hasNutritionHistory: Bool = false
    @Published var hasSleepData: Bool = false

    // Nutrition
    @Published var todayCalories: Double = 0
    @Published var calorieGoal: Double = 2000
    @Published var todayProtein: Double = 0
    @Published var proteinGoal: Double = 150
    @Published var todayCarbs: Double = 0
    @Published var carbsGoal: Double = 250
    @Published var todayFat: Double = 0
    @Published var fatGoal: Double = 65

    // Weekly nutrition adherence
    @Published var weeklyNutritionData: [DayAdherence] = []
    @Published var weeklyAdherenceScore: Int = 0

    // Sleep patterns
    @Published var avgSleepHours: Double = 0
    @Published var sleepConsistencyScore: Int = 0
    @Published var sleepTrend: TrendDirection = .stable

    // Workout streak
    @Published var workoutStreak: Int = 0
    @Published var lastWorkoutDate: Date?
    @Published var lastWorkout: WorkoutSummary?
    @Published var lastWorkoutImprovement: String?

    // Scores (kept for compact display)
    @Published var recoveryScore: Double = 70
    @Published var recoveryStatus: String?
    @Published var readinessScore: Double = 70
    @Published var recommendedIntensity: String = "moderate"

    // Smart Dashboard data
    @Published var dashboardData: DashboardResponse?
    @Published var enhancedRecovery: EnhancedRecoveryResponse?
    @Published var progressSummary: ProgressSummary?
    @Published var recommendations: [SmartRecommendation] = []
    @Published var weeklySummary: WeeklySummary?

    // Narrative dashboard data
    @Published var commitments: [CommitmentSlot] = []
    @Published var cardPriorityOrder: [PrioritizedCard] = []
    @Published var causalAnnotations: [CausalAnnotation] = []
    @Published var greetingContext: String = ""
    @Published var readinessNarrative: String = ""
    @Published var dailyActions: [DailyAction] = []

    func causalAnnotation(for metric: String) -> CausalAnnotation? {
        causalAnnotations.first { $0.metricName == metric }
    }

    var personalizedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }
        if let name = displayName, !name.isEmpty {
            return "\(timeGreeting), \(name)!"
        }
        return "\(timeGreeting)!"
    }

    /// Filter recommendations whose actionRoute duplicates a commitment's actionRoute
    var filteredRecommendations: [SmartRecommendation] {
        let commitmentRoutes = Set(commitments.compactMap { $0.actionRoute })
        return recommendations.filter { rec in
            guard let route = rec.actionRoute else { return true }
            return !commitmentRoutes.contains(route)
        }
    }

    @Published var isLoading = false

    func loadData() async {
        isLoading = true

        // Load user profile first to determine if new user
        await loadUserProfile()

        // Load independent data sources in parallel
        async let workoutTask: () = loadTodaysWorkout()
        async let nutritionTask: () = loadNutrition()
        async let weeklyNutritionTask: () = loadWeeklyNutrition()
        async let workoutsTask: () = loadWorkouts()
        async let sleepTask: () = loadSleepPatterns()

        _ = await (workoutTask, nutritionTask, weeklyNutritionTask, workoutsTask, sleepTask)

        // Only load predictions/dashboard if not a new user (needs data)
        if !isNewUser {
            await loadDashboardData()
        }

        isLoading = false
    }

    private func loadDashboardData() async {
        // Try narrative endpoint first, fall back to legacy dashboard
        do {
            let narrative = try await APIService.shared.getNarrativeDashboard()
            enhancedRecovery = narrative.enhancedRecovery
            progressSummary = narrative.progress
            recommendations = narrative.recommendations
            weeklySummary = narrative.weeklySummary

            // Narrative-specific fields
            commitments = narrative.commitments
            cardPriorityOrder = narrative.cardPriorityOrder
            causalAnnotations = narrative.causalAnnotations
            greetingContext = narrative.greetingContext
            readinessNarrative = narrative.readinessNarrative
            dailyActions = narrative.dailyActions

            // Compact scores
            recoveryScore = narrative.enhancedRecovery.score
            recoveryStatus = narrative.enhancedRecovery.status
            readinessScore = narrative.readinessScore
            recommendedIntensity = narrative.readinessIntensity
            return
        } catch {
            print("Narrative dashboard unavailable, falling back: \(error)")
        }

        // Fallback to legacy dashboard
        do {
            let dashboard = try await APIService.shared.getDashboardData()
            dashboardData = dashboard
            enhancedRecovery = dashboard.enhancedRecovery
            progressSummary = dashboard.progress
            recommendations = dashboard.recommendations
            weeklySummary = dashboard.weeklySummary

            recoveryScore = dashboard.enhancedRecovery.score
            recoveryStatus = dashboard.enhancedRecovery.status
            readinessScore = dashboard.readinessScore
            recommendedIntensity = dashboard.readinessIntensity
        } catch {
            print("Failed to load dashboard data: \(error)")
            await loadPredictions()
        }
    }

    private func loadUserProfile() async {
        do {
            let user = try await APIService.shared.getProfile()
            let calendar = Calendar.current
            let daysSinceCreation = calendar.dateComponents([.day], from: user.createdAt, to: Date()).day ?? 0

            displayName = user.displayName
            // User is "new" if account is < 7 days old
            isNewUser = daysSinceCreation < 7
        } catch {
            print("Failed to load user profile: \(error)")
            // Default to showing new user experience
            isNewUser = true
        }
    }

    private func loadTodaysWorkout() async {
        do {
            let workout = try await APIService.shared.getTodaysWorkout()

            // Update hasSetupTrainingPlan based on whether they have a plan
            hasSetupTrainingPlan = workout.hasPlan

            // Only show the card if they have a plan
            if workout.hasPlan {
                todaysWorkout = workout
            } else {
                todaysWorkout = nil
            }
        } catch {
            print("Failed to load today's workout: \(error)")
            hasSetupTrainingPlan = false
            todaysWorkout = nil
        }
    }

    private func loadNutrition() async {
        do {
            let summary = try await APIService.shared.getDailyNutritionSummary()
            todayCalories = summary.totalCalories
            todayProtein = summary.totalProteinG
            todayCarbs = summary.totalCarbsG
            todayFat = summary.totalFatG
            calorieGoal = summary.calorieTarget
            proteinGoal = summary.proteinTargetG
            carbsGoal = summary.carbsTargetG
            fatGoal = summary.fatTargetG

            // Check if user has logged any food today
            hasLoggedMeal = summary.totalCalories > 0
        } catch {
            print("Failed to load nutrition: \(error)")
        }
    }

    private func loadWeeklyNutrition() async {
        do {
            let weeklyData = try await APIService.shared.getWeeklyNutritionSummary()

            // Check if there's any real data (non-zero calories on any day)
            let daysWithData = weeklyData.filter { $0.totalCalories > 0 }
            hasNutritionHistory = daysWithData.count >= 2  // Need at least 2 days of data to show chart

            guard hasNutritionHistory else {
                weeklyNutritionData = []
                weeklyAdherenceScore = 0
                return
            }

            // Convert API data to DayAdherence format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            var adherenceData: [DayAdherence] = []
            var onTargetDays = 0

            for day in weeklyData {
                guard let date = dateFormatter.date(from: day.date) else { continue }

                let progress = day.calorieTarget > 0 ? day.totalCalories / day.calorieTarget : 0
                let isOnTarget = progress >= 0.8 && progress <= 1.2

                if isOnTarget && day.totalCalories > 0 { onTargetDays += 1 }

                adherenceData.append(DayAdherence(
                    day: date,
                    progress: progress,
                    isOnTarget: isOnTarget
                ))
            }

            weeklyNutritionData = adherenceData
            weeklyAdherenceScore = daysWithData.isEmpty ? 0 : Int((Double(onTargetDays) / Double(daysWithData.count)) * 100)
        } catch {
            print("Failed to load weekly nutrition: \(error)")
            hasNutritionHistory = false
            weeklyNutritionData = []
            weeklyAdherenceScore = 0
        }
    }

    private func loadSleepPatterns() async {
        do {
            let history = try await APIService.shared.getSleepHistory(days: 7)

            // Check if there's any sleep data
            hasSleepData = !history.isEmpty
            hasLoggedSleep = !history.isEmpty

            guard hasSleepData else {
                avgSleepHours = 0
                sleepConsistencyScore = 0
                sleepTrend = .stable
                return
            }

            let analytics = try await APIService.shared.getSleepAnalytics(days: 7)
            avgSleepHours = analytics.avgDurationHours
            sleepConsistencyScore = Int(analytics.consistencyScore)

            // Determine trend based on recent data
            if analytics.avgDurationHours > 7.5 {
                sleepTrend = .up
            } else if analytics.avgDurationHours < 6.5 {
                sleepTrend = .down
            } else {
                sleepTrend = .stable
            }
        } catch {
            print("Failed to load sleep patterns: \(error)")
            hasSleepData = false
            avgSleepHours = 0
            sleepConsistencyScore = 0
            sleepTrend = .stable
        }
    }

    private func loadWorkouts() async {
        do {
            let workouts = try await APIService.shared.getWorkouts(days: 30)

            // Update checklist status
            hasLoggedWorkout = !workouts.isEmpty

            // Calculate streak
            workoutStreak = calculateStreak(from: workouts)

            // Get last workout
            if let last = workouts.first {
                lastWorkoutDate = last.startedAt
                lastWorkout = WorkoutSummary(
                    name: last.workoutType.displayName,
                    icon: last.workoutType.icon,
                    date: last.startedAt,
                    duration: last.durationMinutes ?? 0,
                    calories: last.caloriesBurned
                )

                // Check for improvement (simplified - could compare to previous similar workout)
                if let load = last.trainingLoad, load > 50 {
                    lastWorkoutImprovement = "+\(Int(load - 40))%"
                }
            }
        } catch {
            print("Failed to load workouts: \(error)")
        }
    }

    private func loadPredictions() async {
        async let recovery = APIService.shared.getRecoveryPrediction()
        async let readiness = APIService.shared.getReadinessPrediction()

        do {
            let (rec, read) = try await (recovery, readiness)

            recoveryScore = rec.score
            recoveryStatus = rec.status.rawValue

            readinessScore = read.score
            recommendedIntensity = read.recommendedIntensity
        } catch {
            print("Failed to load predictions: \(error)")
        }
    }

    private func calculateStreak(from workouts: [Workout]) -> Int {
        guard !workouts.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique workout days sorted descending
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.startedAt) })
            .sorted(by: >)

        guard let mostRecent = workoutDays.first else { return 0 }

        // Allow up to 2-day gap from today (rest day tolerance)
        let daysSinceLast = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if daysSinceLast > 2 { return 0 }

        // Walk backwards through workout days, allowing 1 rest day between each
        var streak = 1
        var previousWorkoutDay = mostRecent

        for day in workoutDays.dropFirst() {
            let gap = calendar.dateComponents([.day], from: day, to: previousWorkoutDay).day ?? 0
            if gap <= 2 {
                // 1 = consecutive, 2 = one rest day between — both count
                streak += 1
                previousWorkoutDay = day
            } else {
                break  // Streak broken — more than 1 rest day gap
            }
        }

        return streak
    }

    func refresh() async {
        await loadData()
    }
}

#Preview {
    TodayView()
        .environmentObject(HealthKitService.shared)
        .environmentObject(TabRouter.shared)
}
