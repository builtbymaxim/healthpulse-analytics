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
            if authService.isRestoringSession {
                // Minimal splash while checking stored session
                ZStack {
                    AppTheme.backgroundDark
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            } else if authService.isAuthenticated {
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
        .animation(.easeInOut(duration: 0.3), value: authService.isRestoringSession)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.isOnboardingComplete)
        .onChange(of: authService.isAuthenticated) { _, authenticated in
            if authenticated {
                showGreeting = true
                Task { await TodayViewModel.shared.loadData() }
            } else {
                TodayViewModel.shared.resetForLogout()
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
    @ObservedObject private var workoutStore = WorkoutSessionStore.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tabRouter.selectedTab) {
                TodayView()
                    .tag(AppTab.dashboard)
                NutritionView()
                    .tag(AppTab.nutrition)
                WorkoutTabView()
                    .tag(AppTab.workout)
                SleepView()
                    .tag(AppTab.sleep)
                ProfileView()
                    .tag(AppTab.profile)
            }
            .toolbar(.hidden, for: .tabBar)

            VStack(spacing: 0) {
                LiveWorkoutBar()
                CustomTabBar(selectedTab: $tabRouter.selectedTab)
            }
        }
        .animation(MotionTokens.entrance, value: workoutStore.isActive && !workoutStore.isPresenting)
        .fullScreenCover(isPresented: $workoutStore.isPresenting) {
            if let vm = workoutStore.activeViewModel {
                WorkoutExecutionView(viewModel: vm) { prs in
                    workoutStore.endWorkout(prs: prs)
                }
            }
        }
        .sheet(isPresented: $tabRouter.showSocialView) {
            NavigationStack {
                SocialView()
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
