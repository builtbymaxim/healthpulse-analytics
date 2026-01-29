//
//  InsightsView.swift
//  HealthPulse
//
//  AI-generated insights and correlations
//

import SwiftUI

struct InsightsView: View {
    @State private var insights: [Insight] = []
    @State private var correlations: [Correlation] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .frame(height: 200)
                    } else {
                        // Insights section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Insights")
                                .font(.headline)
                                .padding(.horizontal)

                            if insights.isEmpty {
                                EmptyStateCard(
                                    icon: "lightbulb",
                                    title: "No Insights Yet",
                                    message: "Keep logging your data to discover personalized insights."
                                )
                                .padding(.horizontal)
                            } else {
                                ForEach(insights) { insight in
                                    InsightCard(insight: insight)
                                        .padding(.horizontal)
                                }
                            }
                        }

                        Divider()
                            .padding(.horizontal)

                        // Correlations section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Correlations")
                                .font(.headline)
                                .padding(.horizontal)

                            if correlations.isEmpty {
                                EmptyStateCard(
                                    icon: "link",
                                    title: "No Correlations Yet",
                                    message: "Log more data to discover patterns in your health metrics."
                                )
                                .padding(.horizontal)
                            } else {
                                ForEach(Array(correlations.enumerated()), id: \.offset) { _, correlation in
                                    CorrelationCard(correlation: correlation)
                                        .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Insights")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        // Load demo data
        insights = [
            Insight(
                id: UUID(),
                category: .recommendation,
                title: "Optimize Your Sleep",
                description: "Your recovery scores are 15% higher on days following 7.5+ hours of sleep.",
                data: nil,
                createdAt: Date()
            ),
            Insight(
                id: UUID(),
                category: .trend,
                title: "Wellness Improving",
                description: "Your overall wellness has improved by 8% over the past 2 weeks.",
                data: nil,
                createdAt: Date()
            ),
            Insight(
                id: UUID(),
                category: .achievement,
                title: "Consistency Streak",
                description: "You've logged data for 7 days in a row. Great job!",
                data: nil,
                createdAt: Date()
            )
        ]

        correlations = [
            Correlation(
                factorA: "sleep",
                factorB: "recovery",
                correlation: 0.72,
                insight: "Strong positive relationship between sleep and recovery scores.",
                dataPoints: 30,
                confidence: 0.85
            ),
            Correlation(
                factorA: "stress",
                factorB: "hrv",
                correlation: -0.58,
                insight: "Higher stress levels are associated with lower HRV readings.",
                dataPoints: 25,
                confidence: 0.78
            ),
            Correlation(
                factorA: "exercise",
                factorB: "mood",
                correlation: 0.45,
                insight: "Workout days tend to correlate with better mood scores.",
                dataPoints: 20,
                confidence: 0.65
            )
        ]

        // Try to load from API
        do {
            let apiInsights = try await APIService.shared.getInsights()
            if !apiInsights.isEmpty {
                insights = apiInsights
            }

            let apiCorrelations = try await APIService.shared.getCorrelations()
            if !apiCorrelations.isEmpty {
                correlations = apiCorrelations
            }
        } catch {
            print("Failed to load from API: \(error)")
        }

        isLoading = false
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.category.icon)
                    .foregroundStyle(categoryColor)
                    .frame(width: 30)

                Text(insight.title)
                    .font(.headline)

                Spacer()
            }

            Text(insight.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(categoryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }

    var categoryColor: Color {
        switch insight.category {
        case .correlation: return .blue
        case .anomaly: return .red
        case .trend: return .purple
        case .recommendation: return .green
        case .achievement: return .yellow
        }
    }
}

struct CorrelationCard: View {
    let correlation: Correlation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(correlation.factorA.capitalized)
                    .fontWeight(.semibold)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)

                Text(correlation.factorB.capitalized)
                    .fontWeight(.semibold)

                Spacer()

                Text(String(format: "%+.2f", correlation.correlation))
                    .font(.headline)
                    .foregroundStyle(correlationColor)
            }

            // Correlation bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(correlationColor)
                        .frame(width: geo.size.width * abs(correlation.correlation))
                }
            }
            .frame(height: 8)

            Text(correlation.insight)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(correlation.dataPoints) data points")
                Spacer()
                Text("Confidence: \(Int(correlation.confidence * 100))%")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var correlationColor: Color {
        correlation.correlation >= 0 ? .green : .red
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    InsightsView()
}
