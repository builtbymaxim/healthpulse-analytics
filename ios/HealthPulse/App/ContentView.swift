//
//  ContentView.swift
//  HealthPulse
//
//  Main navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView(selectedTab: $selectedTab)
            } else {
                AuthView()
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "heart.fill")
                }
                .tag(0)

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            LogView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle.fill")
                }
                .tag(2)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(HealthKitService.shared)
}
