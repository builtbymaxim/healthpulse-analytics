//
//  WelcomeChecklistCard.swift
//  HealthPulse
//
//  Onboarding checklist card shown to new users on the dashboard.
//

import SwiftUI

struct WelcomeChecklistCard: View {
    let displayName: String?
    let hasLoggedWorkout: Bool
    let hasLoggedMeal: Bool
    let hasLoggedSleep: Bool
    let hasSetupTrainingPlan: Bool
    let onWorkoutTap: () -> Void
    let onMealTap: () -> Void
    let onSleepTap: () -> Void
    let onTrainingPlanTap: () -> Void

    private var completedCount: Int {
        [hasLoggedWorkout, hasLoggedMeal, hasLoggedSleep, hasSetupTrainingPlan].filter { $0 }.count
    }

    private var personalizedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }
        if let name = displayName, !name.isEmpty {
            return "\(timeGreeting), \(name)!"
        }
        return "\(timeGreeting)!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Getting Started")
                        .font(.headline)
                    Text("Let's build your routine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completedCount)/4")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.primary.opacity(0.15))
                    .foregroundStyle(AppTheme.primary)
                    .clipShape(Capsule())
            }

            // Checklist items
            VStack(spacing: 12) {
                ChecklistItem(
                    isCompleted: hasLoggedWorkout,
                    title: "Complete your first workout",
                    icon: "dumbbell.fill",
                    action: onWorkoutTap
                )

                ChecklistItem(
                    isCompleted: hasLoggedMeal,
                    title: "Log today's meals",
                    icon: "fork.knife",
                    action: onMealTap
                )

                ChecklistItem(
                    isCompleted: hasLoggedSleep,
                    title: "Track your sleep",
                    icon: "moon.zzz.fill",
                    action: onSleepTap
                )

                ChecklistItem(
                    isCompleted: hasSetupTrainingPlan,
                    title: "Set up a training plan",
                    icon: "calendar.badge.clock",
                    action: onTrainingPlanTap
                )
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

struct ChecklistItem: View {
    let isCompleted: Bool
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isCompleted {
                HapticsManager.shared.light()
                action()
            }
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)

                // Icon
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? .secondary : AppTheme.primary)
                    .frame(width: 24)

                // Title
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted, color: .secondary)

                Spacer()

                if !isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}
