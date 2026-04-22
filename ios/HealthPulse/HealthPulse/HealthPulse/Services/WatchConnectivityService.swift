//
//  WatchConnectivityService.swift
//  HealthPulse
//
//  iPhone-side WatchConnectivity bridge.
//  Sends workout state, readiness, and commitments to the Watch.
//  Receives "Hit it!" tap commands and refresh requests back.
//

import Foundation
import Combine
import WatchConnectivity

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isReachable = false

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send workout state to Watch (real-time)

    /// Called whenever the active exercise, set, or rest state changes.
    func sendWorkoutState(
        exerciseName: String,
        exerciseIndex: Int,
        setNumber: Int,
        totalSets: Int,
        isResting: Bool,
        restEndDate: Date?,
        isActive: Bool
    ) {
        let state = WatchWorkoutState(
            exerciseName: exerciseName,
            exerciseIndex: exerciseIndex,
            setNumber: setNumber,
            totalSets: totalSets,
            isResting: isResting,
            restEndDate: restEndDate,
            isActive: isActive
        )
        sendMessage(.workoutState(state))
    }

    func sendWorkoutEnded() {
        sendMessage(.workoutEnded)
    }

    // MARK: - Send readiness + commitments to Watch (background)

    func sendReadinessUpdate(
        score: Double,
        intensity: String,
        narrative: String,
        topFactor: String
    ) {
        let data = WatchReadinessData(
            score: score,
            recommendedIntensity: intensity,
            narrative: narrative,
            topFactor: topFactor,
            updatedAt: Date()
        )
        transferUserInfo(.readinessUpdate(data))
    }

    func sendCommitmentsUpdate(_ commitments: [CommitmentSlot]) {
        let watchCommitments = commitments.map {
            WatchCommitment(
                slot: $0.slot,
                title: $0.title,
                subtitle: $0.subtitle,
                icon: $0.icon,
                loadModifier: $0.loadModifier
            )
        }
        transferUserInfo(.commitmentsUpdate(watchCommitments))
    }

    // MARK: - Private send helpers

    private func sendMessage(_ message: WatchMessage) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message.encode(), replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message.encode())
        }
    }

    private func transferUserInfo(_ message: WatchMessage) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(message.encode())
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Receives "Hit it!" tap commands and refresh requests from the Watch.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.decode(from: message) else { return }
        Task { @MainActor in
            switch watchMessage {
            case .hitIt(let exerciseIndex, let setIndex):
                WorkoutSessionStore.shared.activeViewModel?.markSetCompleted(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex
                )
            case .requestRefresh:
                // Re-send latest readiness if available — TodayViewModel will handle
                NotificationCenter.default.post(name: .watchRequestedRefresh, object: nil)
            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let watchRequestedRefresh = Notification.Name("watchRequestedRefresh")
}
