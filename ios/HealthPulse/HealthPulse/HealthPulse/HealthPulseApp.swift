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
    @StateObject private var notificationService = NotificationService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .environmentObject(notificationService)
                .task {
                    await notificationService.requestAuthorization()
                }
                .onChange(of: authService.isAuthenticated) { authenticated in
                    if authenticated {
                        Task {
                            await notificationService.scheduleAllNotifications()
                        }
                    } else {
                        notificationService.cancelAllNotifications()
                    }
                }
        }
    }
}
