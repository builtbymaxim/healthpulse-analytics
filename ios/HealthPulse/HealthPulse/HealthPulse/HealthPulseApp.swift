//
//  HealthPulseApp.swift
//  HealthPulse
//
//  Main app entry point
//

import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct HealthPulseApp: App {

    init() {
        FirebaseApp.configure()
    }
    @StateObject private var authService = AuthService.shared
    @StateObject private var healthKitService = HealthKitService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var calendarSyncService = CalendarSyncService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .environmentObject(notificationService)
                .environmentObject(calendarSyncService)
                .environmentObject(networkMonitor)
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
                    switch phase {
                    case .active:
                        Task { await calendarSyncService.syncIfNeeded() }
                        // Return from background — release the background task token
                        ActiveWorkoutManager.shared.endBackgroundTask()
                    case .background:
                        // Keep the workout timer alive while backgrounded
                        if ActiveWorkoutManager.shared.isWorkoutActive {
                            ActiveWorkoutManager.shared.beginBackgroundTask()
                        }
                    default:
                        break
                    }
                }
        }
    }
}
