//
//  ActionCardCarousel.swift
//  HealthPulse
//
//  Animated sequential action card system — shows one action at a time
//  with slide-away animations as actions are completed.
//

import SwiftUI

struct ActionCardCarousel: View {
    let actions: [DailyAction]
    let onActionTap: (String) -> Void

    private var pendingActions: [DailyAction] {
        actions.filter { !$0.isCompleted }
    }

    private var completedCount: Int {
        actions.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress indicator
            if !actions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(actions) { action in
                        Capsule()
                            .fill(action.isCompleted ? AppTheme.primary : AppTheme.surface2)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 4)
            }

            if let current = pendingActions.first {
                ActionPromptCard(action: current) {
                    onActionTap(current.actionRoute)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(current.id)
            } else if !actions.isEmpty {
                // All done
                allCaughtUpCard
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(MotionTokens.entrance, value: pendingActions.map(\.id))
    }

    private var allCaughtUpCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("All caught up!")
                    .font(.headline)
                Text("You've completed all your actions for now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ActionPromptCard: View {
    let action: DailyAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: action.icon)
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let prompt = action.prompt, !prompt.isEmpty {
                        Text(prompt)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    Text(action.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(AppTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
