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
    @StateObject private var calendarSyncService = CalendarSyncService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .environmentObject(notificationService)
                .environmentObject(calendarSyncService)
                .task {
                    await notificationService.requestAuthorization()
                }
                .onChange(of: authService.isAuthenticated) { _, authenticated in
                    if authenticated {
                        Task {
                            await notificationService.scheduleAllNotifications()
                        }
                        calendarSyncService.checkAuthorizationStatus()
                    } else {
                        notificationService.cancelAllNotifications()
                        calendarSyncService.cleanupOnLogout()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await calendarSyncService.syncIfNeeded()
                        }
                    }
                }
        }
    }
}
