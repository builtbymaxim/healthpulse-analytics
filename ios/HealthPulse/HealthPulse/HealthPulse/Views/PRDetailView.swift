//
//  PRDetailView.swift
//  HealthPulse
//
//  Line chart showing exercise progress over time with PR milestones.
//

import SwiftUI
import Charts

struct PRDetailView: View {
    let exerciseName: String
    @State private var progress: [ProgressPoint] = []
    @State private var isLoading = true
    @State private var selectedDays = 90
    @State private var errorMessage: String?

    private let periodOptions = [30, 60, 90]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                } else if let error = errorMessage {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Could not load data",
                        message: error,
                        actionTitle: "Retry"
                    ) {
                        Task { await loadData() }
                    }
                } else if progress.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No data yet",
                        message: "Complete some workouts with \(exerciseName) to see your progress."
                    )
                } else {
                    // Chart
                    progressChart
                        .padding(.horizontal)

                    // Stats summary
                    statsSummary
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .onChange(of: selectedDays) { _, _ in
            Task { await loadData() }
        }
    }

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Progression")
                .font(.headline)

            Chart(progress) { point in
                if let date = dateFromString(point.date) {
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Weight", point.bestWeight)
                    )
                    .foregroundStyle(AppTheme.primary.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Weight", point.bestWeight)
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Weight", point.bestWeight)
                    )
                    .foregroundStyle(AppTheme.primary)
                    .symbolSize(20)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))kg")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, progress.count / 5))) { value in
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let latest = progress.last {
                    statCard(title: "Current Best", value: "\(Int(latest.bestWeight))kg", icon: "scalemass.fill")
                    statCard(title: "Est. 1RM", value: "\(Int(latest.estimated1RM))kg", icon: "flame.fill")
                }
                if let first = progress.first, let last = progress.last {
                    let change = last.bestWeight - first.bestWeight
                    statCard(
                        title: "Change",
                        value: "\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))kg",
                        icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                        color: change >= 0 ? .green : .red
                    )
                }
                statCard(title: "Sessions", value: "\(progress.count)", icon: "calendar")
            }
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCard(title: String, value: String, icon: String, color: Color = AppTheme.primary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.surface2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dateFromString(_ str: String) -> Date? {
        // Backend returns started_at as full ISO 8601 datetime with timezone
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }
        // Fallback: date-only string
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: str)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.getExerciseProgress(exerciseName: exerciseName, days: selectedDays)
            progress = response.progress
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
