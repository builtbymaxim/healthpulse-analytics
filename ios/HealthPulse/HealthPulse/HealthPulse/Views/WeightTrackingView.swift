//
//  WeightTrackingView.swift
//  HealthPulse
//
//  Dedicated weight tracking view with chart, trend analysis, and quick logging.
//

import SwiftUI
import Charts

struct WeightTrackingView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var summary: WeightSummaryResponse?
    @State private var isLoading = true
    @State private var selectedDays = 30
    @State private var weightInput = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isWeightFocused: Bool

    private let periodOptions = [7, 30, 90]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick log section
                    quickLogSection
                        .padding(.horizontal)

                    // Period selector
                    Picker("Period", selection: $selectedDays) {
                        ForEach(periodOptions, id: \.self) { days in
                            Text("\(days)d").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(height: 200)
                    } else if let summary, !summary.entries.isEmpty {
                        // Current stats
                        statsRow(summary: summary)
                            .padding(.horizontal)

                        // Chart
                        weightChart(summary: summary)
                            .padding(.horizontal)
                    } else {
                        EmptyStateView(
                            icon: "scalemass",
                            title: "No weight data yet",
                            message: "Log your first weight above to start tracking your progress."
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Weight Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .onChange(of: selectedDays) { _, _ in
                Task { await loadData() }
            }
        }
    }

    private var quickLogSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .foregroundStyle(AppTheme.primary)

                TextField("Weight (kg)", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isWeightFocused)

                Button {
                    Task { await logWeight() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(width: 60)
                    } else {
                        Text("Log")
                            .font(.subheadline.bold())
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .disabled(weightInput.isEmpty || isSubmitting || !networkMonitor.isConnected)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statsRow(summary: WeightSummaryResponse) -> some View {
        HStack(spacing: 16) {
            if let current = summary.current {
                statPill(title: "Current", value: String(format: "%.1f", current), unit: "kg")
            }
            if let weeklyAvg = summary.weeklyAvg {
                statPill(title: "Weekly Avg", value: String(format: "%.1f", weeklyAvg), unit: "kg")
            }
            if let change = summary.changeFromStart {
                let color: Color = change < 0 ? .green : change > 0 ? .orange : .secondary
                statPill(
                    title: "Change",
                    value: "\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))",
                    unit: "kg",
                    color: color
                )
            }
        }
    }

    private func statPill(title: String, value: String, unit: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func weightChart(summary: WeightSummaryResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weight History")
                    .font(.headline)
                Spacer()
                if let trend = summary.trendDirection {
                    Label(trend.capitalized, systemImage: trendIcon(trend))
                        .font(.caption)
                        .foregroundStyle(trendColor(trend))
                }
            }

            Chart {
                ForEach(summary.entries) { entry in
                    if let date = dateFromString(entry.date) {
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Weight", entry.value)
                        )
                        .foregroundStyle(AppTheme.primary.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Weight", entry.value)
                        )
                        .foregroundStyle(AppTheme.primary.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", date),
                            y: .value("Weight", entry.value)
                        )
                        .foregroundStyle(AppTheme.primary)
                        .symbolSize(16)
                    }
                }

                // Goal line
                if let goal = summary.goal {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal: \(Int(goal))kg")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
            }
            .chartYScale(domain: chartYDomain(summary))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, summary.entries.count / 5))) { value in
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chartYDomain(_ summary: WeightSummaryResponse) -> ClosedRange<Double> {
        let values = summary.entries.map(\.value)
        let minVal = (values.min() ?? 60) - 2
        let maxVal = (values.max() ?? 100) + 2
        if let goal = summary.goal {
            return min(minVal, goal - 2)...max(maxVal, goal + 2)
        }
        return minVal...maxVal
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "losing": return "arrow.down.right"
        case "gaining": return "arrow.up.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "losing": return .green
        case "gaining": return .orange
        default: return .secondary
        }
    }

    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }

    private func loadData() async {
        isLoading = true
        do {
            summary = try await APIService.shared.getWeightSummary(days: selectedDays)
        } catch {
            // Keep existing data if available
        }
        isLoading = false
    }

    private func logWeight() async {
        guard let value = Double(weightInput) else {
            errorMessage = "Enter a valid number"
            return
        }
        errorMessage = nil
        isSubmitting = true
        do {
            try await APIService.shared.logWeight(value)
            weightInput = ""
            isWeightFocused = false
            HapticsManager.shared.success()
            NotificationCenter.default.post(name: .weightLogged, object: nil)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            HapticsManager.shared.error()
        }
        isSubmitting = false
    }
}
