//
//  HealthPulseWatchApp.swift
//  HealthPulseWatch
//
//  Entry point for the Apple Watch companion app.
//
//  SETUP: Add this directory as a new watchOS App target in Xcode:
//    File > New > Target > watchOS > Watch App
//    Name: HealthPulseWatch
//    Add all files in this directory to the new target.
//    Enable WatchConnectivity in Signing & Capabilities.
//

import SwiftUI

@main
struct HealthPulseWatchApp: App {
    @StateObject private var workoutStore = WatchWorkoutStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutStore)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var workoutStore: WatchWorkoutStore

    var body: some View {
        if workoutStore.isActive {
            WorkoutView()
                .environmentObject(workoutStore)
        } else {
            IdleView()
        }
    }
}

struct IdleView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("HealthPulse")
                .font(.headline)
            Text("Start a workout on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
