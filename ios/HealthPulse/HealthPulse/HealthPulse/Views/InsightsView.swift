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
        if insights.isEmpty {
            isLoading = true
        }

        do {
            async let insightsTask = APIService.shared.getInsights()
            async let correlationsTask = APIService.shared.getCorrelations()

            let (apiInsights, apiCorrelations) = try await (insightsTask, correlationsTask)
            insights = apiInsights
            correlations = apiCorrelations
        } catch {
            print("Failed to load from API: \(error)")
            // insights/correlations stay empty, showing the empty state cards
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
