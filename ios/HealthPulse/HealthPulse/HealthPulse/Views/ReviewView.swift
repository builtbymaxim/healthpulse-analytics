//
//  ReviewView.swift
//  HealthPulse
//
//  Weekly and monthly review with workout, nutrition, sleep, and weight insights.
//

import SwiftUI
import Charts

enum ReviewPeriod: String {
    case weekly, monthly

    var displayName: String {
        switch self {
        case .weekly: return "Weekly Review"
        case .monthly: return "Monthly Review"
        }
    }

    var icon: String {
        switch self {
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        }
    }
}

struct ReviewView: View {
    let period: ReviewPeriod
    @State private var review: ReviewResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let review {
                    reviewContent(review)
                } else if let errorMessage {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't Load Review",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) {
                        Task { await loadData() }
                    }
                } else {
                    EmptyStateView(
                        icon: period.icon,
                        title: "No Data Yet",
                        message: "Keep logging your workouts, meals, and metrics to see your \(period.rawValue) review."
                    )
                }
            }
            .background(AppTheme.backgroundDark)
            .navigationTitle(period.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surface2)
                    .frame(height: 120)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 20)
        .redacted(reason: .placeholder)
    }

    // MARK: - Content

    @ViewBuilder
    private func reviewContent(_ review: ReviewResponse) -> some View {
        VStack(spacing: 20) {
            // Overall score
            overallScoreCard(review)

            // Date range
            Text("\(review.startDate) — \(review.endDate)")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            // Highlights
            if !review.highlights.isEmpty {
                highlightsCard(review.highlights)
            }

            // Workouts
            workoutsCard(review)

            // PRs
            if !review.prs.isEmpty {
                prsCard(review.prs)
            }

            // Nutrition
            nutritionCard(review)

            // Sleep
            sleepCard(review)

            // Weight
            if review.weightStart != nil || review.weightEnd != nil {
                weightCard(review)
            }

            Spacer(minLength: 40)
        }
        .padding(.top, 12)
    }

    // MARK: - Overall Score

    private func overallScoreCard(_ review: ReviewResponse) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                ProgressRing(
                    progress: review.overallScore / 100.0,
                    lineWidth: 12,
                    color: scoreColor(review.overallScore)
                )
                .frame(width: 100, height: 100)
                .overlay {
                    VStack(spacing: 2) {
                        Text("\(Int(review.overallScore))")
                            .font(.title.bold())
                        Text("/ 100")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Overall Score")
                    .font(.headline)

                Text(scoreLabel(review.overallScore))
                    .font(.subheadline)
                    .foregroundStyle(scoreColor(review.overallScore))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    // MARK: - Highlights

    private func highlightsCard(_ highlights: [String]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Highlights", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)

                ForEach(Array(highlights.enumerated()), id: \.offset) { _, highlight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.primary)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(highlight)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Workouts

    private func workoutsCard(_ review: ReviewResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Workouts", systemImage: "figure.run")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)

                HStack(spacing: 16) {
                    statBubble(
                        value: "\(review.workoutsCompleted)",
                        label: "Completed",
                        color: AppTheme.primary
                    )
                    statBubble(
                        value: "\(review.workoutsPlanned)",
                        label: "Planned",
                        color: .blue
                    )
                    statBubble(
                        value: formatVolume(review.totalVolume),
                        label: "Volume",
                        color: .purple
                    )
                }

                // Volume change
                if review.volumeChangePct != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: review.volumeChangePct > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f%% volume vs. previous", abs(review.volumeChangePct)))
                    }
                    .font(.caption)
                    .foregroundStyle(review.volumeChangePct > 0 ? .green : .orange)
                }

                // Adherence bar
                if review.workoutsPlanned > 0 {
                    let adherence = Double(review.workoutsCompleted) / Double(review.workoutsPlanned)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adherence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.primary)
                                    .frame(width: geo.size.width * min(adherence, 1.0), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - PRs

    private func prsCard(_ prs: [[String: AnyCodable]]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)

                ForEach(Array(prs.enumerated()), id: \.offset) { _, pr in
                    if let exercise = pr["exercise_name"]?.value as? String,
                       let weight = pr["weight"]?.value as? Double {
                        HStack {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(.yellow)
                            Text(exercise)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.1f kg", weight))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Nutrition

    private func nutritionCard(_ review: ReviewResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Nutrition", systemImage: "fork.knife")
                    .font(.headline)
                    .foregroundStyle(.orange)

                HStack(spacing: 16) {
                    statBubble(
                        value: "\(Int(review.nutritionAdherencePct))%",
                        label: "Adherence",
                        color: .orange
                    )
                    statBubble(
                        value: "\(Int(review.avgCalories))",
                        label: "Avg Cal",
                        color: .red
                    )
                    statBubble(
                        value: "\(Int(review.avgProtein))g",
                        label: "Avg Protein",
                        color: .blue
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Sleep

    private func sleepCard(_ review: ReviewResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Sleep", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)

                HStack(spacing: 16) {
                    statBubble(
                        value: String(format: "%.1f", review.avgSleepHours),
                        label: "Avg Hours",
                        color: .purple
                    )
                    statBubble(
                        value: "\(Int(review.sleepConsistency))%",
                        label: "Consistency",
                        color: .indigo
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Weight

    private func weightCard(_ review: ReviewResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundStyle(.cyan)

                HStack(spacing: 16) {
                    if let start = review.weightStart {
                        statBubble(
                            value: String(format: "%.1f", start),
                            label: "Start (kg)",
                            color: .cyan
                        )
                    }
                    if let end = review.weightEnd {
                        statBubble(
                            value: String(format: "%.1f", end),
                            label: "End (kg)",
                            color: .cyan
                        )
                    }
                    if let change = review.weightChange {
                        statBubble(
                            value: String(format: "%+.1f", change),
                            label: "Change",
                            color: change < 0 ? .green : (change > 0 ? .orange : .gray)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Fair" }
        return "Needs Work"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            review = try await APIService.shared.getReview(period: period.rawValue)
            withAnimation(MotionTokens.entrance) {
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    ReviewView(period: .weekly)
}
