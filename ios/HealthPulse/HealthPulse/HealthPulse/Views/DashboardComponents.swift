//
//  DashboardComponents.swift
//  HealthPulse
//
//  Smart Dashboard UI components for TodayView
//

import SwiftUI

// MARK: - Enhanced Recovery Card

struct EnhancedRecoveryCard: View {
    let recovery: EnhancedRecoveryResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery")
                        .font(.headline)
                    Text(recovery.status.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(recovery.statusColor)
                }

                Spacer()

                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: recovery.score / 100)
                        .stroke(recovery.statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(recovery.score))")
                        .font(.system(size: 18, weight: .bold))
                        .contentTransition(.numericText())
                }
            }

            Divider()

            // Contributing factors
            VStack(spacing: 12) {
                ForEach(recovery.factors) { factor in
                    RecoveryFactorRow(factor: factor)
                }
            }

            // Sleep deficit warning
            if let deficit = recovery.sleepDeficitHours, deficit > 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Sleep deficit: \(String(format: "%.1f", deficit))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // Primary recommendation
            Text(recovery.primaryRecommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct RecoveryFactorRow: View {
    let factor: RecoveryFactor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: factor.icon)
                .font(.system(size: 16))
                .foregroundStyle(factor.impactColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.displayName)
                    .font(.subheadline)
                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(factor.impactColor)
                        .frame(width: geometry.size.width * (factor.score / 100))
                }
            }
            .frame(width: 60, height: 8)
        }
    }

    var formattedValue: String {
        switch factor.name {
        case "sleep_hours":
            return "\(String(format: "%.1f", factor.value))h"
        case "training_load":
            return "\(Int(factor.value)) load"
        case "hrv":
            return "\(Int(factor.value)) ms"
        default:
            return "\(Int(factor.value))"
        }
    }
}

// MARK: - Progress Dashboard Section

struct ProgressDashboardSection: View {
    let progress: ProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                SectionHeaderLabel(text: "Progress")
                Spacer()
                Text(volumeTrendText)
                    .font(.caption)
                    .foregroundStyle(progress.volumeTrendColor)
            }

            // Key lifts horizontal scroll
            if !progress.keyLifts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(progress.keyLifts) { lift in
                            KeyLiftCard(lift: lift)
                        }
                    }
                }
            }

            // Volume summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedVolume)
                        .font(.title3.bold())
                }

                Spacer()

                // Recent PRs badge
                if !progress.recentPrs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("\(progress.recentPrs.count) PR\(progress.recentPrs.count == 1 ? "" : "s")")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            // Muscle balance grid
            if !progress.muscleBalance.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Muscle Recovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(progress.muscleBalance.prefix(6)) { muscle in
                            MuscleBalanceChip(muscle: muscle)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }

    var volumeTrendText: String {
        let pct = progress.volumeTrendPct
        if pct > 0 {
            return "↑ \(Int(pct))% vs last week"
        } else if pct < 0 {
            return "↓ \(Int(abs(pct)))% vs last week"
        }
        return "Same as last week"
    }

    var formattedVolume: String {
        let vol = progress.totalVolumeWeek
        if vol >= 1000 {
            return String(format: "%.1fk kg", vol / 1000)
        }
        return "\(Int(vol)) kg"
    }
}

struct KeyLiftCard: View {
    let lift: LiftProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shortName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(lift.currentValue)) kg")
                .font(.headline)
                .contentTransition(.numericText())

            HStack(spacing: 2) {
                Text("\(lift.changeSymbol)\(String(format: "%.1f", lift.changeValue))")
                    .font(.caption.bold())
                    .foregroundStyle(lift.changeColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var shortName: String {
        // Shorten common exercise names
        let name = lift.exerciseName
        if name.contains("Bench Press") { return "Bench" }
        if name.contains("Squat") { return "Squat" }
        if name.contains("Deadlift") { return "Deadlift" }
        if name.contains("Overhead") { return "OHP" }
        if name.contains("Row") { return "Row" }
        return String(name.prefix(8))
    }
}

struct MuscleBalanceChip: View {
    let muscle: MuscleBalance

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(muscle.statusColor)
                .frame(width: 6, height: 6)

            Text(muscle.category.capitalized)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.surface1)
        .clipShape(Capsule())
    }
}

// MARK: - Smart Recommendations Section

struct SmartRecommendationsSection: View {
    let recommendations: [SmartRecommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderLabel(text: "For You")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendations) { rec in
                        RecommendationCard(recommendation: rec)
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: SmartRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: recommendation.categoryIcon)
                    .font(.caption)
                    .foregroundStyle(recommendation.categoryColor)

                Text(recommendation.category.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recommendation.title)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(recommendation.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 180, alignment: .leading)
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let summary: WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderLabel(text: "This Week")

            // 2x2 Grid of stats
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                WeeklyStatItem(
                    icon: "dumbbell.fill",
                    value: "\(summary.workoutsCompleted)/\(summary.workoutsPlanned)",
                    label: "Workouts",
                    color: workoutCompletionColor
                )

                WeeklyStatItem(
                    icon: "bed.double.fill",
                    value: "\(Int(summary.avgSleepScore))",
                    label: "Sleep Score",
                    color: sleepScoreColor
                )

                WeeklyStatItem(
                    icon: "fork.knife",
                    value: "\(Int(summary.nutritionAdherencePct))%",
                    label: "Nutrition",
                    color: nutritionColor
                )

                if let bestDay = summary.bestDay {
                    WeeklyStatItem(
                        icon: "star.fill",
                        value: bestDay,
                        label: "Best Day",
                        color: .yellow
                    )
                } else {
                    WeeklyStatItem(
                        icon: "calendar",
                        value: "-",
                        label: "Best Day",
                        color: .gray
                    )
                }
            }

            // Highlights
            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.highlights, id: \.self) { highlight in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.primary)
                            Text(highlight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }

    var workoutCompletionColor: Color {
        guard summary.workoutsPlanned > 0 else { return .gray }
        let pct = Double(summary.workoutsCompleted) / Double(summary.workoutsPlanned)
        if pct >= 1 { return .green }
        if pct >= 0.5 { return .orange }
        return .red
    }

    var sleepScoreColor: Color {
        if summary.avgSleepScore >= 80 { return .green }
        if summary.avgSleepScore >= 60 { return .orange }
        return .red
    }

    var nutritionColor: Color {
        if summary.nutritionAdherencePct >= 80 { return .green }
        if summary.nutritionAdherencePct >= 50 { return .orange }
        return .red
    }
}

struct WeeklyStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Readiness Header

struct ReadinessHeaderView: View {
    let readinessScore: Double
    let greetingContext: String
    let narrative: String

    private var readinessColor: Color {
        if readinessScore >= 70 { return .green }
        if readinessScore >= 40 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 14) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: readinessScore / 100)
                    .stroke(readinessColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(MotionTokens.ring, value: readinessScore)

                Text("\(Int(readinessScore))")
                    .font(.system(size: 16, weight: .bold))
                    .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(greetingContext.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(readinessColor)

                Text(narrative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Commitment Strip

struct CommitmentStripView: View {
    let commitments: [CommitmentSlot]
    var onTap: ((String?) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(commitments) { slot in
                CommitmentCard(slot: slot) {
                    onTap?(slot.actionRoute)
                }
            }
        }
    }
}

struct CommitmentCard: View {
    let slot: CommitmentSlot
    var onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticsManager.shared.light()
            onTap()
        } label: {
            VStack(spacing: 8) {
                // Slot label badge
                Text(slot.slotLabel)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(slot.slotColor)
                    .clipShape(Capsule())

                // Icon circle
                ZStack {
                    Circle()
                        .fill(slot.slotColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: slot.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(slot.slotColor)
                }

                // Title & subtitle
                Text(slot.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(slot.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                // Load modifier badge
                if let modifier = slot.loadModifier {
                    LoadModifierBadge(modifier: modifier)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(AppTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(CommitmentButtonStyle())
    }
}

struct CommitmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Daily Actions Card

struct DailyActionsCard: View {
    let actions: [DailyAction]
    var onTap: ((String) -> Void)?

    private var pendingActions: [DailyAction] {
        actions.filter { !$0.isCompleted }.sorted { $0.priority < $1.priority }
    }

    private var completedActions: [DailyAction] {
        actions.filter { $0.isCompleted }
    }

    private var allDone: Bool {
        !actions.isEmpty && pendingActions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Today's Actions")
                    .font(.headline)
                Spacer()
                if !actions.isEmpty {
                    Text("\(completedActions.count)/\(actions.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(allDone ? Color.green.opacity(0.15) : AppTheme.primary.opacity(0.15))
                        .foregroundStyle(allDone ? .green : AppTheme.primary)
                        .clipShape(Capsule())
                }
            }

            if allDone {
                // All caught up state
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're all caught up!")
                            .font(.subheadline.bold())
                        Text("All daily actions completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(pendingActions) { action in
                        DailyActionRow(action: action) {
                            onTap?(action.actionRoute)
                        }
                    }
                    ForEach(completedActions) { action in
                        DailyActionRow(action: action) {}
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct DailyActionRow: View {
    let action: DailyAction
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if !action.isCompleted {
                HapticsManager.shared.light()
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(action.isCompleted ? .green : .secondary)

                Image(systemName: action.icon)
                    .font(.subheadline)
                    .foregroundStyle(action.isCompleted ? .secondary : AppTheme.primary)
                    .frame(width: 24)

                Text(action.title)
                    .font(.subheadline)
                    .foregroundStyle(action.isCompleted ? .secondary : .primary)
                    .strikethrough(action.isCompleted, color: .secondary)

                Spacer()

                if !action.isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(action.isCompleted)
    }
}

struct LoadModifierBadge: View {
    let modifier: String

    private var isReducing: Bool {
        modifier.hasPrefix("reduce")
    }

    private var label: String {
        isReducing ? "EASE OFF" : "PUSH IT"
    }

    private var color: Color {
        isReducing ? .orange : .green
    }

    var body: some View {
        Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Causal Recovery Card

struct CausalRecoveryCard: View {
    let recovery: EnhancedRecoveryResponse
    let annotation: CausalAnnotation?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnhancedRecoveryCard(recovery: recovery)

            // Causal annotation banner
            if let annotation = annotation {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)

                    Text("mainly because \(annotation.primaryDriver)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.primary.opacity(0.08))
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0
                    )
                )
            }
        }
    }
}

// MARK: - Dashboard Card Router

struct DashboardCardRouter: View {
    let cardType: String
    @ObservedObject var viewModel: TodayViewModel
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        switch cardType {
        case "workout":
            if let todaysWorkout = viewModel.todaysWorkout {
                TodayWorkoutCard(
                    workout: todaysWorkout,
                    onTap: { tabRouter.navigateTo(.workout) }
                )
            }
        case "nutrition":
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
        case "recovery":
            if let recovery = viewModel.enhancedRecovery {
                CausalRecoveryCard(
                    recovery: recovery,
                    annotation: viewModel.causalAnnotation(for: "recovery")
                )
            }
        case "sleep":
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
            }
        case "streak":
            WorkoutStreakCard(
                streakDays: viewModel.workoutStreak,
                lastWorkoutDate: viewModel.lastWorkoutDate
            )
            .onTapGesture {
                tabRouter.navigateTo(.workout)
                HapticsManager.shared.light()
            }
        case "progress":
            if let progress = viewModel.progressSummary {
                ProgressDashboardSection(progress: progress)
            }
        case "weekly":
            if let summary = viewModel.weeklySummary {
                WeeklySummaryCard(summary: summary)
            }
        case "nutrition_adherence":
            if viewModel.hasNutritionHistory {
                NutritionAdherenceCard(
                    weeklyData: viewModel.weeklyNutritionData,
                    adherenceScore: viewModel.weeklyAdherenceScore
                )
                .onTapGesture {
                    tabRouter.navigateTo(.nutrition)
                    HapticsManager.shared.light()
                }
            }
        case "last_workout":
            if let lastWorkout = viewModel.lastWorkout {
                LastWorkoutCard(
                    workout: lastWorkout,
                    improvement: viewModel.lastWorkoutImprovement
                )
                .onTapGesture {
                    tabRouter.navigateTo(.workout)
                    HapticsManager.shared.light()
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("Enhanced Recovery Card") {
    EnhancedRecoveryCard(recovery: EnhancedRecoveryResponse(
        score: 72,
        status: "moderate",
        factors: [
            RecoveryFactor(name: "sleep_hours", value: 6.5, score: 65, impact: "negative", recommendation: "Aim for 7-9 hours"),
            RecoveryFactor(name: "training_load", value: 320, score: 85, impact: "positive", recommendation: nil),
            RecoveryFactor(name: "hrv", value: 45, score: 70, impact: "neutral", recommendation: nil)
        ],
        primaryRecommendation: "Prioritize sleep tonight - aim for 8+ hours.",
        sleepDeficitHours: 1.5,
        estimatedFullRecoveryHours: 12
    ))
    .padding()
}

// MARK: - Deficit Radar Card (Phase 12B)

struct DeficitRadarCard: View {
    let targets: ReadinessTargetsResponse
    let onFixDeficit: () -> Void

    private var urgencyColor: Color {
        switch targets.deficit.urgency {
        case "critical": return .red
        case "behind": return .orange
        default: return .green
        }
    }

    private var calorieProgress: Double {
        guard targets.deficit.caloriesTarget > 0 else { return 0 }
        return min(targets.deficit.caloriesConsumed / targets.deficit.caloriesTarget, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Fuel")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: targets.isTrainingDay ? "flame.fill" : "leaf.fill")
                            .foregroundStyle(targets.isTrainingDay ? .orange : .green)
                        Text(targets.isTrainingDay ? "Training Day" : "Rest Day")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Readiness badge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: targets.readinessScore / 100)
                        .stroke(urgencyColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(targets.readinessScore))")
                        .font(.system(size: 18, weight: .bold))
                        .contentTransition(.numericText())
                }
            }

            // Adjustment badges
            if !targets.adjustments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(targets.adjustments) { adj in
                            Text(adj.adjustment)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(urgencyColor.opacity(0.15))
                                .foregroundStyle(urgencyColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Divider()

            // Calorie progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Calories")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(targets.deficit.caloriesConsumed)) / \(Int(targets.deficit.caloriesTarget)) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: calorieProgress)
                    .tint(urgencyColor)

                // Protein remaining
                HStack {
                    Text("Protein")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(targets.deficit.proteinConsumedG)) / \(Int(targets.deficit.proteinTargetG)) g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: targets.deficit.proteinTargetG > 0
                    ? min(targets.deficit.proteinConsumedG / targets.deficit.proteinTargetG, 1.0)
                    : 0
                )
                    .tint(.blue)
            }

            // Urgency message
            HStack(spacing: 8) {
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 8, height: 8)
                Text(targets.deficit.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Fix My Deficit CTA
            if targets.deficit.urgency != "on_track" && targets.deficit.caloriesRemaining > 100 {
                Button(action: onFixDeficit) {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text("Fix My Deficit")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(urgencyColor.opacity(0.15))
                    .foregroundStyle(urgencyColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

#Preview("Weekly Summary Card") {
    WeeklySummaryCard(summary: WeeklySummary(
        workoutsCompleted: 3,
        workoutsPlanned: 4,
        avgSleepScore: 75,
        nutritionAdherencePct: 85,
        bestDay: "Tuesday",
        highlights: ["Completed 3 workouts!", "Great sleep quality"]
    ))
    .padding()
}
