//
//  TabRouter.swift
//  HealthPulse
//
//  Handles navigation between tabs from anywhere in the app
//

import SwiftUI
import Combine

enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case nutrition = 1
    case workout = 2
    case sleep = 3
    case profile = 4
}

@MainActor
class TabRouter: ObservableObject {
    static let shared = TabRouter()

    @Published var selectedTab: AppTab = .dashboard
    @Published var showStrengthWorkout = false
    @Published var showRunningWorkout = false
    @Published var showFoodLog = false

    private init() {}

    func navigateTo(_ tab: AppTab) {
        selectedTab = tab
    }

    func startStrengthWorkout() {
        selectedTab = .workout
        showStrengthWorkout = true
    }

    func startRunningWorkout() {
        selectedTab = .workout
        showRunningWorkout = true
    }

    func logFood() {
        selectedTab = .nutrition
        showFoodLog = true
    }
}
