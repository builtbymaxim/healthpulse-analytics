//
//  TodayViewModel.swift
//  HealthPulse
//
//  View model for the main dashboard (TodayView).
//

import SwiftUI
import Combine

@MainActor
class TodayViewModel: ObservableObject {
    static let shared = TodayViewModel()
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

    // Metabolic readiness
    @Published var readinessTargets: ReadinessTargetsResponse?
    @Published var showDeficitFix = false

    // Social (dashboard card)
    @Published var socialRankEntry: LeaderboardEntry?
    @Published var activePartnersCount: Int = 0
    @Published var socialOptIn: Bool = false
    private var cancellables = Set<AnyCancellable>()

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

    @Published var isLoading = true
    @Published var loadError: String?
    @Published var showRecoveryDetail = false
    @Published var showRecoveryFuelInfo = false

    private var isLoadInProgress = false
    private var hasLoadedOnce = false
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        setupCrossTabListeners()
        observeAuthProfile()
    }

    /// Subscribe to AuthService.$currentUser so social data loads reactively even when
    /// the ViewModel's own loadUserProfile() fails or completes before AuthService finishes.
    private func observeAuthProfile() {
        AuthService.shared.$currentUser
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                guard let self else { return }
                let optIn = user.settings?.socialOptIn ?? false
                self.socialOptIn = optIn
                if optIn, self.socialRankEntry == nil, !self.isLoadInProgress {
                    Task { await self.loadSocialData() }
                }
            }
            .store(in: &cancellables)
    }

    private func isCancelledError(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func setupCrossTabListeners() {
        let nc = NotificationCenter.default
        notificationObservers.append(nc.addObserver(forName: .foodLogged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !isLoadInProgress else { return }
                // Cache already invalidated at the mutation site in APIService.
                // Only reload nutrition totals — the narrative dashboard revalidates on its own SWR TTL.
                await loadNutrition()
            }
        })
        notificationObservers.append(nc.addObserver(forName: .workoutCompleted, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !isLoadInProgress else { return }
                APIService.shared.invalidateCache(matching: "/workouts")
                APIService.shared.invalidateCache(matching: "/training-plans")
                APIService.shared.invalidateCache(matching: "/predictions")
                async let w: () = loadTodaysWorkout()
                async let d: () = loadDashboardData()
                _ = await (w, d)
            }
        })
        notificationObservers.append(nc.addObserver(forName: .weightLogged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !isLoadInProgress else { return }
                APIService.shared.invalidateCache(matching: "/predictions")
                await loadDashboardData()
            }
        })
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func resetForLogout() {
        isLoading = false
        loadError = nil
        isLoadInProgress = false
        hasLoadedOnce = false
        dashboardData = nil
        enhancedRecovery = nil
        progressSummary = nil
        recommendations = []
        weeklySummary = nil
        readinessTargets = nil
        readinessNarrative = ""
        commitments = []
        dailyActions = []
        causalAnnotations = []
        greetingContext = ""
        todaysWorkout = nil
        lastWorkout = nil
        socialRankEntry = nil
        weeklyNutritionData = []
        todayCalories = 0; todayProtein = 0; todayCarbs = 0; todayFat = 0
        recoveryScore = 70; readinessScore = 70
        isNewUser = true
    }

    func loadData() async {
        guard !isLoadInProgress else { return }
        isLoadInProgress = true
        defer {
            isLoadInProgress = false
            hasLoadedOnce = true
        }
        loadError = nil
        if !hasLoadedOnce { isLoading = true }

        // Fire HealthKit refresh + sync concurrently — doesn't gate UI reveal
        Task {
            await HealthKitService.shared.refreshTodayData()
            await HealthKitService.shared.syncHealthKitToBackend()
        }

        // Load profile in parallel with other independent sources
        async let profileTask: () = loadUserProfile()
        async let workoutTask: () = loadTodaysWorkout()
        async let nutritionTask: () = loadNutrition()
        async let weeklyNutritionTask: () = loadWeeklyNutrition()
        async let workoutsTask: () = loadWorkouts()
        async let sleepTask: () = loadSleepPatterns()

        _ = await (profileTask, workoutTask, nutritionTask, weeklyNutritionTask, workoutsTask, sleepTask)

        // Reveal UI immediately — AI data loads silently behind the scenes
        withAnimation(MotionTokens.entrance) { isLoading = false }

        // Phase 2 — Slow AI data (narrative dashboard + predictions, for established users)
        if !isNewUser {
            async let dashboardTask:   () = loadDashboardData()
            async let predictionsTask: () = loadPredictions()
            _ = await (dashboardTask, predictionsTask)
        }
        // Social loads regardless of account age — gated internally by socialOptIn.
        // Decoupled from isNewUser so a failed loadUserProfile() doesn't block it.
        await loadSocialData()
    }

    private func loadDashboardData() async {
        // Try narrative endpoint first, fall back to legacy dashboard
        // Do NOT reset data upfront — keep old values visible during load
        do {
            let narrative = try await APIService.shared.getNarrativeDashboard()
            withAnimation(MotionTokens.entrance) {
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
            }
            pushReadinessToWatch()
            pushCommitmentsToWatch()
            pushDailySnapshot()
            return
        } catch {
            if isCancelledError(error) { return }
            print("Narrative dashboard unavailable, falling back: \(error)")
        }

        // Fallback to legacy dashboard — clear narrative-only fields here
        do {
            let dashboard = try await APIService.shared.getDashboardData()
            withAnimation(MotionTokens.entrance) {
                dashboardData = dashboard
                enhancedRecovery = dashboard.enhancedRecovery
                progressSummary = dashboard.progress
                recommendations = dashboard.recommendations
                weeklySummary = dashboard.weeklySummary

                recoveryScore = dashboard.enhancedRecovery.score
                recoveryStatus = dashboard.enhancedRecovery.status
                readinessScore = dashboard.readinessScore
                recommendedIntensity = dashboard.readinessIntensity

                // Only clear narrative fields on actual fallback
                commitments = []
                dailyActions = []
                readinessNarrative = ""
                greetingContext = ""
                causalAnnotations = []
            }
            pushReadinessToWatch()
            pushDailySnapshot()
        } catch {
            if isCancelledError(error) { return }
            print("Failed to load dashboard data: \(error)")
            // On total failure, keep existing data — don't reset
            await loadPredictions()
            // If we have no cached data at all, signal retry UI
            if enhancedRecovery == nil {
                loadError = "Couldn't load all dashboard data"
            }
        }
    }

    private func loadUserProfile() async {
        do {
            let user = try await APIService.shared.getProfile()
            let calendar = Calendar.current
            let daysSinceCreation = calendar.dateComponents([.day], from: user.createdAt, to: Date()).day ?? 0

            displayName = user.displayName
            socialOptIn = user.settings?.socialOptIn ?? false
            // User is "new" if account is < 7 days old
            isNewUser = daysSinceCreation < 7
        } catch {
            if isCancelledError(error) { return }
            print("Failed to load user profile: \(error)")
            isNewUser = true
            if displayName == nil {
                loadError = "Could not connect. Pull down to retry."
            }
        }
    }

    private func loadSocialData() async {
        guard socialOptIn else { return }
        do {
            async let leaderboardTask = APIService.shared.getLeaderboard(category: "workout_streaks")
            async let partnersTask = APIService.shared.getPartners()
            let (leaderboard, partners) = try await (leaderboardTask, partnersTask)
            socialRankEntry = leaderboard.first { $0.isCurrentUser }
            activePartnersCount = partners.filter { $0.status == "active" }.count
        } catch {
            // Social card simply won't show
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
            if isCancelledError(error) { return }
            print("Failed to load today's workout: \(error)")
            hasSetupTrainingPlan = false
            todaysWorkout = nil
        }
    }

    private func loadNutrition() async {
        // Fire both nutrition API calls in parallel
        async let summaryFetch = APIService.shared.getDailyNutritionSummary()
        async let readinessFetch = APIService.shared.getReadinessTargets()

        do {
            let summary = try await summaryFetch
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
            if isCancelledError(error) { return }
            print("Failed to load nutrition: \(error)")
        }

        // Load readiness targets (graceful fallback — if it fails, NutritionProgressCard still shows)
        do {
            readinessTargets = try await readinessFetch
        } catch {
            if isCancelledError(error) { return }
            print("Readiness targets unavailable: \(error)")
            readinessTargets = nil
        }

        pushDailySnapshot()
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
                    isOnTarget: isOnTarget,
                    caloriesActual: day.totalCalories,
                    caloriesTarget: day.calorieTarget
                ))
            }

            weeklyNutritionData = adherenceData
            weeklyAdherenceScore = daysWithData.isEmpty ? 0 : Int((Double(onTargetDays) / Double(daysWithData.count)) * 100)
        } catch {
            if isCancelledError(error) { return }
            print("Failed to load weekly nutrition: \(error)")
            hasNutritionHistory = false
            weeklyNutritionData = []
            weeklyAdherenceScore = 0
        }
    }

    private func loadSleepPatterns() async {
        do {
            // Fire both API calls in parallel — analytics is checked but not always needed
            async let historyFetch = APIService.shared.getSleepHistory(days: 7)
            async let analyticsFetch = APIService.shared.getSleepAnalytics(days: 7)

            let history = try await historyFetch
            hasLoggedSleep = !history.isEmpty

            guard !history.isEmpty else {
                avgSleepHours = 0
                sleepConsistencyScore = 0
                sleepTrend = .stable
                hasSleepData = false
                return
            }

            let analytics = try await analyticsFetch

            // Batch all sleep state at once — hasSleepData last to prevent 0.0h flash
            avgSleepHours = analytics.avgDurationHours
            sleepConsistencyScore = Int(analytics.consistencyScore)
            if analytics.avgDurationHours > 7.5 {
                sleepTrend = .up
            } else if analytics.avgDurationHours < 6.5 {
                sleepTrend = .down
            } else {
                sleepTrend = .stable
            }
            hasSleepData = true
        } catch {
            if isCancelledError(error) { return }
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
            if isCancelledError(error) { return }
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
            if isCancelledError(error) { return }
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

    // MARK: - Watch Sync

    private func pushReadinessToWatch() {
        WatchConnectivityService.shared.sendReadinessUpdate(
            score: readinessScore,
            intensity: recommendedIntensity,
            narrative: readinessNarrative,
            topFactor: causalAnnotations.first?.driverFactor ?? ""
        )
    }

    private func pushCommitmentsToWatch() {
        WatchConnectivityService.shared.sendCommitmentsUpdate(commitments)
    }

    private func pushDailySnapshot() {
        let healthKit = HealthKitService.shared
        let snapshot = WatchDailySnapshot(
            calories: todayCalories,
            calorieGoal: calorieGoal,
            protein: todayProtein,
            proteinGoal: proteinGoal,
            carbs: todayCarbs,
            carbsGoal: carbsGoal,
            fat: todayFat,
            fatGoal: fatGoal,
            sleepHours: healthKit.lastSleepHours,
            sleepDeep: healthKit.sleepStageHours?.deep,
            sleepREM: healthKit.sleepStageHours?.rem,
            sleepCore: healthKit.sleepStageHours?.core,
            steps: healthKit.todaySteps,
            stepGoal: 10000,
            restingHR: healthKit.restingHeartRate,
            hrv: healthKit.hrv,
            hrvTrend: nil,
            isTrainingDay: todaysWorkout?.hasPlan ?? false,
            workoutName: todaysWorkout?.workoutName,
            workoutStreak: workoutStreak,
            recoveryScore: recoveryScore,
            vo2Max: healthKit.vo2Max,
            respiratoryRate: healthKit.respiratoryRate
        )
        WatchConnectivityService.shared.pushDailySnapshot(snapshot)
    }
}
