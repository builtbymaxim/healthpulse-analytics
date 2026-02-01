//
//  ContentView.swift
//  HealthPulse
//
//  Main navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var healthKit: HealthKitService
    @StateObject private var tabRouter = TabRouter.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.isOnboardingComplete {
                    MainTabView()
                        .environmentObject(tabRouter)
                } else {
                    OnboardingView()
                        .environmentObject(healthKit)
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.isOnboardingComplete)
    }
}

struct MainTabView: View {
    @EnvironmentObject var tabRouter: TabRouter

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            // Dashboard - main overview
            TodayView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppTab.dashboard)

            // Nutrition - food tracking
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(AppTab.nutrition)

            // Workout - exercise tracking
            WorkoutTabView()
                .tabItem {
                    Label("Workout", systemImage: "figure.run")
                }
                .tag(AppTab.workout)

            // Sleep tracking
            SleepView()
                .tabItem {
                    Label("Sleep", systemImage: "moon.zzz.fill")
                }
                .tag(AppTab.sleep)

            // Profile & settings
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
