//
//  ReadinessGlanceView.swift
//  HealthPulseWatch
//
//  Shows the daily readiness score, recommended intensity, narrative,
//  and top causal factor. Stale data is shown with an "Updated X ago" badge.
//

import SwiftUI

struct ReadinessGlanceView: View {
    @EnvironmentObject var store: WatchWorkoutStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                scoreRing
                intensityLabel
                narrativeText
                topFactorLabel
                staleBadge
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(.black, for: .navigation)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.requestRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.darkGray), lineWidth: 8)
                .frame(width: 90, height: 90)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: store.readinessScore)

            VStack(spacing: 1) {
                if let score = store.readinessScore {
                    Text("\(Int(score))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("/ 100")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private var ringProgress: Double {
        guard let score = store.readinessScore else { return 0 }
        return min(max(score / 100.0, 0), 1)
    }

    private var ringColor: Color {
        guard let score = store.readinessScore else { return .gray }
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    // MARK: - Labels

    private var intensityLabel: some View {
        Group {
            if !store.recommendedIntensity.isEmpty {
                Text(store.recommendedIntensity.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(ringColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ringColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var narrativeText: some View {
        Group {
            if !store.readinessNarrative.isEmpty {
                Text(store.readinessNarrative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    private var topFactorLabel: some View {
        Group {
            if !store.topFactor.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.caption2)
                    Text(store.topFactor)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var staleBadge: some View {
        Group {
            if let updated = store.readinessUpdatedAt {
                let hours = Int(Date().timeIntervalSince(updated) / 3600)
                if hours >= 1 {
                    Text("Updated \(hours)h ago")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
    }
}
