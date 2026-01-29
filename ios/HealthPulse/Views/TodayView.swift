//
//  TodayView.swift
//  HealthPulse
//
//  Main dashboard view showing today's health status
//

import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()
    @EnvironmentObject var healthKitService: HealthKitService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Score Cards
                    HStack(spacing: 16) {
                        ScoreCard(
                            title: "Recovery",
                            score: viewModel.recoveryScore,
                            status: viewModel.recoveryStatus,
                            color: statusColor(viewModel.recoveryStatus)
                        )

                        ScoreCard(
                            title: "Readiness",
                            score: viewModel.readinessScore,
                            subtitle: viewModel.recommendedIntensity,
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    // Wellness Score
                    WellnessCard(
                        score: viewModel.wellnessScore,
                        components: viewModel.wellnessComponents,
                        trend: viewModel.wellnessTrend
                    )
                    .padding(.horizontal)

                    // Today's Stats from HealthKit
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Activity")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            MetricTile(
                                icon: "figure.walk",
                                title: "Steps",
                                value: "\(healthKitService.todaySteps.formatted())",
                                color: .green
                            )

                            MetricTile(
                                icon: "flame.fill",
                                title: "Calories",
                                value: "\(Int(healthKitService.todayCalories))",
                                color: .orange
                            )

                            if let hr = healthKitService.restingHeartRate {
                                MetricTile(
                                    icon: "heart.fill",
                                    title: "Resting HR",
                                    value: "\(Int(hr)) bpm",
                                    color: .red
                                )
                            }

                            if let sleep = healthKitService.lastSleepHours {
                                MetricTile(
                                    icon: "bed.double.fill",
                                    title: "Sleep",
                                    value: String(format: "%.1fh", sleep),
                                    color: .purple
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Recommendations
                    if !viewModel.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(viewModel.recommendations, id: \.self) { rec in
                                RecommendationCard(text: rec)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Suggested Workouts
                    if !viewModel.suggestedWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Workouts")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.suggestedWorkouts, id: \.self) { workout in
                                        WorkoutSuggestionCard(name: workout)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Today")
            .refreshable {
                await viewModel.refresh()
                await healthKitService.refreshTodayData()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "recovered": return .green
        case "moderate": return .orange
        case "fatigued": return .red
        default: return .gray
        }
    }
}

// MARK: - Score Card

struct ScoreCard: View {
    let title: String
    let score: Double
    var status: String?
    var subtitle: String?
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(score))")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(width: 100, height: 100)

            if let status = status {
                Text(status.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }

            if let subtitle = subtitle {
                Text(subtitle.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Wellness Card

struct WellnessCard: View {
    let score: Double
    let components: [String: Double]
    let trend: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Wellness")
                        .font(.headline)

                    Text(trendText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(score))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.green)
            }

            // Component bars
            VStack(spacing: 8) {
                ForEach(Array(components.keys.sorted()), id: \.self) { key in
                    if let value = components[key] {
                        ComponentBar(name: key.replacingOccurrences(of: "_", with: " ").capitalized, value: value)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var trendText: String {
        switch trend {
        case "improving": return "Trending up"
        case "declining": return "Trending down"
        default: return "Stable"
        }
    }
}

struct ComponentBar: View {
    let name: String
    let value: Double

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * (value / 100))
                }
            }
            .frame(height: 8)

            Text("\(Int(value))")
                .font(.caption)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if value >= 70 { return .green }
        if value >= 50 { return .orange }
        return .red
    }
}

// MARK: - Metric Tile

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)

            Text(text)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Workout Suggestion Card

struct WorkoutSuggestionCard: View {
    let name: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: workoutIcon)
                .font(.title)
                .foregroundStyle(.green)

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 80, height: 80)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var workoutIcon: String {
        switch name.lowercased() {
        case "running", "run": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "swimming", "swim": return "figure.pool.swim"
        case "strength", "strength training": return "dumbbell.fill"
        case "hiit": return "flame.fill"
        case "yoga": return "figure.yoga"
        case "walking", "walk": return "figure.walk"
        default: return "figure.mixed.cardio"
        }
    }
}

// MARK: - View Model

@MainActor
class TodayViewModel: ObservableObject {
    @Published var recoveryScore: Double = 70
    @Published var recoveryStatus: String?
    @Published var readinessScore: Double = 70
    @Published var recommendedIntensity: String = "moderate"
    @Published var wellnessScore: Double = 70
    @Published var wellnessComponents: [String: Double] = [:]
    @Published var wellnessTrend: String = "stable"
    @Published var recommendations: [String] = []
    @Published var suggestedWorkouts: [String] = []
    @Published var isLoading = false

    func loadData() async {
        isLoading = true

        async let recovery = APIService.shared.getRecoveryPrediction()
        async let readiness = APIService.shared.getReadinessPrediction()
        async let wellness = APIService.shared.getWellnessScore()

        do {
            let (rec, read, well) = try await (recovery, readiness, wellness)

            recoveryScore = rec.score
            recoveryStatus = rec.status.rawValue
            recommendations = rec.recommendations

            readinessScore = read.score
            recommendedIntensity = read.recommendedIntensity
            suggestedWorkouts = read.suggestedWorkoutTypes

            wellnessScore = well.overallScore
            wellnessComponents = well.components
            wellnessTrend = well.trend
        } catch {
            // Use default values on error
            print("Failed to load data: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        await loadData()
    }
}

#Preview {
    TodayView()
        .environmentObject(HealthKitService.shared)
}
