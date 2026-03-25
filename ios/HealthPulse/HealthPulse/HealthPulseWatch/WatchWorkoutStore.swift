//
//  WatchWorkoutStore.swift
//  HealthPulseWatch
//
//  Receives workout state from the iPhone via WatchConnectivity and
//  sends "Hit it!" tap events back.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchWorkoutStore: NSObject, ObservableObject {

    @Published var isActive = false
    @Published var exerciseName = ""
    @Published var setNumber = 1
    @Published var totalSets = 1
    @Published var isResting = false
    @Published var restEndDate: Date? = nil

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Actions

    /// Send "Hit it!" tap to the iPhone.
    func hitIt(exerciseIndex: Int, setIndex: Int) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "hitIt", "exerciseIndex": exerciseIndex, "setIndex": setIndex],
            replyHandler: nil,
            errorHandler: nil
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchWorkoutStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            switch message["type"] as? String {
            case "workoutState":
                self.isActive = (message["isActive"] as? Bool) ?? false
                self.exerciseName = (message["exerciseName"] as? String) ?? ""
                self.setNumber = (message["setNumber"] as? Int) ?? 1
                self.totalSets = (message["totalSets"] as? Int) ?? 1
                self.isResting = (message["isResting"] as? Bool) ?? false
                if let ts = message["restEndDate"] as? Double {
                    self.restEndDate = Date(timeIntervalSince1970: ts)
                } else {
                    self.restEndDate = nil
                }
            case "workoutEnded":
                self.isActive = false
                self.isResting = false
                self.restEndDate = nil
            default:
                break
            }
        }
    }
}
