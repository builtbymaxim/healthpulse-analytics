//
//  HealthPulseApp.swift
//  HealthPulse
//
//  Main app entry point
//

import SwiftUI

@main
struct HealthPulseApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var healthKitService = HealthKitService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
        }
    }
}
