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
//    Add WatchMessage.swift (Shared/) to this target's membership.
//

import SwiftUI

@main
struct HealthPulseWatchApp: App {
    @StateObject private var workoutStore = WatchWorkoutStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(workoutStore)
        }
    }
}

// MARK: - Root Navigation

struct RootView: View {
    @EnvironmentObject var workoutStore: WatchWorkoutStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ReadinessGlanceView()
                .environmentObject(workoutStore)
                .tag(0)

            CommitmentsView()
                .environmentObject(workoutStore)
                .tag(1)

            workoutTab
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: workoutStore.isActive) { _, isActive in
            if isActive { selectedTab = 2 }
        }
    }

    @ViewBuilder
    private var workoutTab: some View {
        if workoutStore.isActive {
            WorkoutView()
                .environmentObject(workoutStore)
        } else {
            IdleView()
        }
    }
}

// MARK: - Idle View

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
        .containerBackground(.black, for: .navigation)
    }
}
