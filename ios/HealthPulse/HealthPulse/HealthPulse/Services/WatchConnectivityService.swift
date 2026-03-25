//
//  WatchConnectivityService.swift
//  HealthPulse
//
//  iPhone-side WatchConnectivity bridge.
//  Sends active workout state to the Watch and receives "Hit it!" tap commands back.
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

    // MARK: - Send workout state to Watch

    /// Called whenever the active exercise, set, or rest state changes.
    func sendWorkoutState(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        isResting: Bool,
        restEndDate: Date?,
        isActive: Bool
    ) {
        guard WCSession.default.isReachable else { return }
        var message: [String: Any] = [
            "type": "workoutState",
            "exerciseName": exerciseName,
            "setNumber": setNumber,
            "totalSets": totalSets,
            "isResting": isResting,
            "isActive": isActive,
        ]
        if let end = restEndDate {
            message["restEndDate"] = end.timeIntervalSince1970
        }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    func sendWorkoutEnded() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "workoutEnded"], replyHandler: nil, errorHandler: nil)
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

    /// Receives "Hit it!" tap commands from the Watch.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        if type == "hitIt",
           let exerciseIndex = message["exerciseIndex"] as? Int,
           let setIndex = message["setIndex"] as? Int {
            Task { @MainActor in
                WorkoutSessionStore.shared.activeViewModel?.markSetCompleted(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex
                )
            }
        }
    }
}
