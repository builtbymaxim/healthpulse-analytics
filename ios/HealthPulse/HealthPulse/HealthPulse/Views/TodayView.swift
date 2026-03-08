//
//  TodayView.swift
//  HealthPulse
//
//  Main dashboard view - redesigned for actionable insights
//

import SwiftUI
import Combine

struct TodayView: View {
    @ObservedObject private var viewModel = TodayViewModel.shared
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var tabRouter: TabRouter
    @State private var showTrainingPlanSetup = false
    @State private var showWorkoutExecution = false
    @State private var showPRCelebration = false
    @State private var achievedPRs: [PRInfo] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    DashboardSkeletonView()
                } else if let err = viewModel.loadError, viewModel.enhancedRecovery == nil {
                    EmptyStateView(
                        icon: "wifi.slash",
                        title: "Couldn't Load Dashboard",
                        message: err,
                        actionTitle: "Retry"
                    ) {
                        Task { await viewModel.loadData() }
                    }
                    .padding(.top, 80)
                } else {
                    dashboardContent
                }
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
            .sheet(isPresented: $viewModel.showDeficitFix) {
                if let targets = viewModel.readinessTargets {
                    DeficitFixView(deficit: targets.deficit)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $viewModel.showRecoveryDetail) {
                if let recovery = viewModel.enhancedRecovery {
                    RecoveryDetailSheet(recovery: recovery)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $viewModel.showRecoveryFuelInfo) {
                if let targets = viewModel.readinessTargets {
                    RecoveryFuelInfoSheet(targets: targets)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $tabRouter.showWeightTracking) {
                WeightTrackingView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $tabRouter.showWeeklyReview) {
                ReviewView(period: .weekly)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $tabRouter.showMonthlyReview) {
                ReviewView(period: .monthly)
                    .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        VStack(spacing: 20) {
            // 1. Greeting — always visible
            Text(viewModel.personalizedGreeting)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // 2. Readiness Header (narrative-enhanced)
            if !viewModel.readinessNarrative.isEmpty {
                ReadinessHeaderView(
                    readinessScore: viewModel.readinessScore,
                    greetingContext: viewModel.greetingContext,
                    narrative: viewModel.readinessNarrative
                )
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 3. Commitment Strip (NOW / NEXT / TONIGHT)
            if !viewModel.commitments.isEmpty {
                CommitmentStripView(commitments: viewModel.commitments) { route in
                    navigateToRoute(route)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 4. Action Card Carousel (animated sequential prompts)
            if viewModel.isNewUser {
                WelcomeChecklistCard(
                    displayName: nil,
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
                ActionCardCarousel(actions: viewModel.dailyActions) { route in
                    navigateToRoute(route)
                }
                .padding(.horizontal)
            }

            // 5. Today's Workout
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 6. Nutrition — Deficit Radar or Progress Card
            if let targets = viewModel.readinessTargets {
                DeficitRadarCard(targets: targets, onInfo: {
                    viewModel.showRecoveryFuelInfo = true
                    HapticsManager.shared.light()
                }) {
                    viewModel.showDeficitFix = true
                }
                .padding(.horizontal)
            } else {
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
            }

            // 7. Social Rank
            if let socialRank = viewModel.socialRankEntry {
                NavigationLink {
                    SocialView()
                } label: {
                    SocialRankCard(
                        rank: socialRank.rank,
                        streakValue: Int(socialRank.value),
                        activePartners: viewModel.activePartnersCount
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // 8. Last Workout
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

            // 9. Sleep Pattern
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

            // 10. Recovery
            if !viewModel.isNewUser, let recovery = viewModel.enhancedRecovery {
                CausalRecoveryCard(
                    recovery: recovery,
                    annotation: viewModel.causalAnnotation(for: "recovery")
                )
                .onTapGesture {
                    viewModel.showRecoveryDetail = true
                    HapticsManager.shared.light()
                }
                .padding(.horizontal)
            } else if !viewModel.isNewUser && viewModel.readinessNarrative.isEmpty {
                // Fallback: compact scores when no narrative data
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

            // 11. Progress
            if !viewModel.isNewUser, let progress = viewModel.progressSummary {
                ProgressDashboardSection(progress: progress)
                    .padding(.horizontal)
            }

            // 12. Weekly Summary
            if !viewModel.isNewUser, let summary = viewModel.weeklySummary {
                WeeklySummaryCard(summary: summary)
                    .padding(.horizontal)
            }

            // 13. Recommendations
            if !viewModel.isNewUser && !viewModel.filteredRecommendations.isEmpty {
                SmartRecommendationsSection(recommendations: viewModel.filteredRecommendations)
                    .padding(.horizontal)
            }

            // 14. Nutrition Adherence
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

            // 15. Quick Stats Row
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

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
    }

    private func navigateToRoute(_ route: String?) {
        guard let route else { return }
        HapticsManager.shared.light()
        // Support parameterized routes like "nutrition?meal=breakfast"
        let parts = route.split(separator: "?", maxSplits: 1)
        let baseRoute = String(parts[0])
        switch baseRoute {
        case "workout":
            tabRouter.navigateTo(.workout)
        case "nutrition":
            tabRouter.navigateTo(.nutrition)
            if parts.count > 1 {
                // Future: parse meal= param to pre-select meal type
                tabRouter.showFoodLog = true
            }
        case "sleep":
            tabRouter.navigateTo(.sleep)
        case "profile":
            tabRouter.navigateTo(.profile)
        case "weight":
            tabRouter.openWeightTracking()
        case "weekly_review":
            tabRouter.openWeeklyReview()
        case "monthly_review":
            tabRouter.openMonthlyReview()
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

#Preview {
    TodayView()
        .environmentObject(HealthKitService.shared)
        .environmentObject(TabRouter.shared)
}
