//
//  WatchWorkoutStore.swift
//  HealthPulseWatch
//
//  Central Watch data store. Receives workout state, readiness, and commitment
//  data from the iPhone via WatchConnectivity and sends "Hit it!" taps back.
//

import Foundation
import WatchConnectivity
import Combine

private let udReadinessKey = "watchReadinessData"

@MainActor
class WatchWorkoutStore: NSObject, ObservableObject {

    // MARK: - Workout State

    @Published var isActive = false
    @Published var exerciseName = ""
    @Published var exerciseIndex = 0
    @Published var setNumber = 1
    @Published var totalSets = 1
    @Published var isResting = false
    @Published var restEndDate: Date? = nil

    // MARK: - Readiness

    @Published var readinessScore: Double? = nil
    @Published var recommendedIntensity: String = ""
    @Published var readinessNarrative: String = ""
    @Published var topFactor: String = ""
    @Published var readinessUpdatedAt: Date? = nil

    // MARK: - Commitments

    @Published var commitments: [WatchCommitment] = []

    // MARK: - Init

    override init() {
        super.init()
        loadCachedReadiness()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Actions

    /// Send "Hit it!" tap to the iPhone.
    func hitIt(exerciseIndex: Int, setIndex: Int) {
        guard WCSession.default.isReachable else { return }
        let msg = WatchMessage.hitIt(exerciseIndex: exerciseIndex, setIndex: setIndex)
        WCSession.default.sendMessage(msg.encode(), replyHandler: nil, errorHandler: nil)
    }

    /// Ask iPhone to push fresh data.
    func requestRefresh() {
        guard WCSession.default.isReachable else { return }
        let msg = WatchMessage.requestRefresh
        WCSession.default.sendMessage(msg.encode(), replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Incoming message handling

    private func apply(_ message: WatchMessage) {
        switch message {
        case .workoutState(let state):
            let wasActive = isActive
            let wasResting = isResting
            isActive = state.isActive
            exerciseName = state.exerciseName
            exerciseIndex = state.exerciseIndex
            setNumber = state.setNumber
            totalSets = state.totalSets
            isResting = state.isResting
            restEndDate = state.restEndDate

            // Haptics + HealthKit session
            if !wasActive && state.isActive {
                WatchHapticsManager.shared.workoutStarted()
                Task { await WatchHealthKitManager.shared.requestAuthorization() }
                WatchHealthKitManager.shared.startSession()
            }
            if !wasResting && state.isResting, let end = state.restEndDate {
                WatchHapticsManager.shared.startMonitoring(restEndDate: end)
            } else if wasResting && !state.isResting {
                WatchHapticsManager.shared.stopMonitoring()
            }

        case .workoutEnded:
            isActive = false
            isResting = false
            restEndDate = nil
            WatchHapticsManager.shared.stopMonitoring()
            WatchHapticsManager.shared.workoutEnded()
            WatchHealthKitManager.shared.endSession()

        case .readinessUpdate(let data):
            readinessScore = data.score
            recommendedIntensity = data.recommendedIntensity
            readinessNarrative = data.narrative
            topFactor = data.topFactor
            readinessUpdatedAt = data.updatedAt
            cacheReadiness(data)

        case .commitmentsUpdate(let list):
            commitments = list

        default:
            break
        }
    }

    // MARK: - UserDefaults cache (offline readiness)

    private func cacheReadiness(_ data: WatchReadinessData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: udReadinessKey)
        }
    }

    private func loadCachedReadiness() {
        guard let data = UserDefaults.standard.data(forKey: udReadinessKey),
              let cached = try? JSONDecoder().decode(WatchReadinessData.self, from: data)
        else { return }
        readinessScore = cached.score
        recommendedIntensity = cached.recommendedIntensity
        readinessNarrative = cached.narrative
        topFactor = cached.topFactor
        readinessUpdatedAt = cached.updatedAt
    }
}

// MARK: - WCSessionDelegate

extension WatchWorkoutStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    /// Real-time messages (workout state, hit-it responses)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.decode(from: message) else { return }
        Task { @MainActor in self.apply(watchMessage) }
    }

    /// Background-queued messages (readiness, commitments)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let watchMessage = WatchMessage.decode(from: userInfo) else { return }
        Task { @MainActor in self.apply(watchMessage) }
    }
}
