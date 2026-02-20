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
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @StateObject private var tabRouter = TabRouter.shared
    @State private var showGreeting = true

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.isOnboardingComplete {
                    ZStack {
                        MainTabView()
                            .environmentObject(tabRouter)

                        if showGreeting {
                            GreetingView(
                                displayName: authService.currentUser?.displayName
                            ) {
                                showGreeting = false
                            }
                            .transition(.opacity)
                            .zIndex(1)
                        }
                    }
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
        .onChange(of: authService.isAuthenticated) { _, authenticated in
            if authenticated {
                showGreeting = true
            }
        }
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                    Text("No Internet Connection")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.red.gradient)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
                .ignoresSafeArea(edges: .top)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var tabRouter: TabRouter
    @EnvironmentObject var authService: AuthService

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

            // Social - always visible; SocialView handles activation card vs. live content
            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
                .tag(AppTab.social)

            // Profile & settings
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(AppTheme.primary)
        .onChange(of: tabRouter.selectedTab) { _, _ in
            HapticsManager.shared.selection()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
