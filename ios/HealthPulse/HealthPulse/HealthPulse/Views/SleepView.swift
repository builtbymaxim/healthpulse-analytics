//
//  SleepView.swift
//  HealthPulse
//
//  Sleep tracking dashboard with history and analytics
//

import SwiftUI
import Charts

struct SleepView: View {
    @State private var summary: SleepSummary?
    @State private var history: [SleepEntry] = []
    @State private var analytics: SleepAnalytics?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showingLogSheet = false
    @State private var selectedPeriod = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonCard()
                        }
                    } else if let error = error {
                        EmptyStateView(
                            icon: "moon.zzz",
                            title: "Unable to Load",
                            message: error,
                            actionTitle: "Retry",
                            action: { Task { await loadData() } }
                        )
                    } else if summary == nil && history.isEmpty {
                        // No sleep data yet - show empty state
                        EmptyStateView(
                            icon: "moon.zzz",
                            title: "No Sleep Data Yet",
                            message: "Log your first night's sleep to start tracking your rest patterns.",
                            actionTitle: "Log Sleep",
                            action: { showingLogSheet = true }
                        )
                    } else {
                        // Today's Sleep Card
                        if let summary = summary {
                            TodaySleepCard(summary: summary)
                                .staggeredAnimation(index: 0)
                        }

                        // Sleep Stages Card
                        if let summary = summary {
                            SleepStagesCard(summary: summary)
                                .staggeredAnimation(index: 1)
                        }

                        // History Chart
                        if !history.isEmpty {
                            SleepHistoryChart(
                                entries: history,
                                selectedPeriod: $selectedPeriod
                            )
                            .staggeredAnimation(index: 2)
                        }

                        // Analytics Card
                        if let analytics = analytics {
                            SleepAnalyticsCard(analytics: analytics)
                                .staggeredAnimation(index: 3)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                SleepLogSheet { await loadData() }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedPeriod) { _, newPeriod in
                // Reload only history when timeframe changes
                Task {
                    do {
                        history = try await APIService.shared.getSleepHistory(days: newPeriod)
                    } catch {
                        print("Failed to reload sleep history: \(error)")
                    }
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let summaryTask = APIService.shared.getSleepSummary()
            async let historyTask = APIService.shared.getSleepHistory(days: selectedPeriod)
            async let analyticsTask = APIService.shared.getSleepAnalytics(days: 30)

            let (s, h, a) = try await (summaryTask, historyTask, analyticsTask)
            summary = s
            history = h
            analytics = a
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Today's Sleep Card

struct TodaySleepCard: View {
    let summary: SleepSummary

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Last Night")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: summary.trendIcon)
                    Text(summary.qualityTrend.capitalized)
                }
                .font(.subheadline)
                .foregroundStyle(summary.trendColor)
            }

            HStack(spacing: 24) {
                // Duration Ring
                ZStack {
                    ProgressRing(
                        progress: min(summary.durationVsTargetPct / 100, 1.5),
                        lineWidth: 12,
                        color: summary.scoreColor
                    )
                    .frame(width: 100, height: 100)

                    VStack(spacing: 2) {
                        Text(summary.formattedDuration)
                            .font(.title2.bold())
                        Text("of \(Int(summary.targetHours))h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    StatRow(
                        icon: "star.fill",
                        label: "Sleep Score",
                        value: "\(Int(summary.sleepScore))",
                        color: summary.scoreColor
                    )

                    StatRow(
                        icon: "waveform.path.ecg",
                        label: "Quality",
                        value: "\(Int(summary.quality))%",
                        color: .blue
                    )
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
    }
}

// MARK: - Sleep Stages Card

struct SleepStagesCard: View {
    let summary: SleepSummary

    var stages: [(stage: SleepStage, hours: Double)] {
        [
            (.deep, summary.deepSleepHours),
            (.rem, summary.remSleepHours),
            (.light, summary.lightSleepHours),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)

            // Horizontal bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stages, id: \.stage) { item in
                        let pct = item.hours / summary.durationHours
                        Rectangle()
                            .fill(item.stage.color)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 12)

            // Legend
            HStack(spacing: 16) {
                ForEach(stages, id: \.stage) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.stage.color)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.stage.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatHours(item.hours))
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
}

// MARK: - Sleep History Chart

struct SleepHistoryChart: View {
    let entries: [SleepEntry]
    @Binding var selectedPeriod: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $selectedPeriod) {
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Chart(entries) { entry in
                BarMark(
                    x: .value("Date", String(entry.date.suffix(5))),
                    y: .value("Hours", entry.durationHours)
                )
                .foregroundStyle(
                    entry.durationHours >= 7 ? Color.blue : Color.orange
                )
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(values: [0, 4, 8, 12]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hours = value.as(Int.self) {
                            Text("\(hours)h")
                        }
                    }
                }
            }
            .chartYScale(domain: 0...12)

            // Target line note
            HStack {
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 20, height: 2)
                Text("7-9h target range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - Sleep Analytics Card

struct SleepAnalyticsCard: View {
    let analytics: SleepAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("30-Day Analytics")
                    .font(.headline)
                Spacer()
                Text(analytics.trendDescription)
                    .font(.caption)
                    .foregroundStyle(analytics.trendColor)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                AnalyticTile(
                    title: "Avg Duration",
                    value: analytics.formattedAvgDuration,
                    icon: "clock.fill",
                    color: .blue
                )

                AnalyticTile(
                    title: "Avg Score",
                    value: "\(Int(analytics.avgSleepScore))",
                    icon: "star.fill",
                    color: .yellow
                )

                AnalyticTile(
                    title: "Sleep Debt",
                    value: String(format: "%.1fh", analytics.totalSleepDebtHours),
                    icon: "exclamationmark.triangle.fill",
                    color: analytics.totalSleepDebtHours > 10 ? .red : .orange
                )

                AnalyticTile(
                    title: "Consistency",
                    value: "\(Int(analytics.consistencyScore))%",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct AnalyticTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sleep Log Sheet

struct SleepLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: () async -> Void

    // Default: bedtime yesterday at 11pm, wake time now
    @State private var bedTime: Date = {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!
    }()

    @State private var wakeTime: Date = Date()
    @State private var quality = 70.0
    @State private var deepSleepMinutes = 0
    @State private var remSleepMinutes = 0
    @State private var showAdvanced = false
    @State private var isSaving = false
    @State private var error: String?

    var durationHours: Double {
        let interval = wakeTime.timeIntervalSince(bedTime)
        return max(interval / 3600, 0)
    }

    var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Bed Time
                Section {
                    DatePicker(
                        "Bed Time",
                        selection: $bedTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: bedTime) { _, _ in
                        HapticsManager.shared.selection()
                    }
                } header: {
                    Label("When did you go to bed?", systemImage: "bed.double.fill")
                }

                // Wake Time
                Section {
                    DatePicker(
                        "Wake Time",
                        selection: $wakeTime,
                        in: bedTime...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: wakeTime) { _, _ in
                        HapticsManager.shared.selection()
                    }
                } header: {
                    Label("When did you wake up?", systemImage: "sunrise.fill")
                }

                // Calculated Duration
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .font(.headline)
                            .foregroundStyle(durationHours >= 7 ? .green : (durationHours >= 5 ? .orange : .red))
                    }
                }

                // Quality
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sleep Quality")
                            Spacer()
                            Text("\(Int(quality))%")
                                .font(.headline)
                                .foregroundStyle(qualityColor)
                        }

                        Slider(value: $quality, in: 0...100, step: 5)
                            .tint(qualityColor)

                        HStack {
                            Text("Poor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Excellent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("How did you sleep?", systemImage: "star.fill")
                }

                // Advanced Options
                Section {
                    DisclosureGroup("Sleep Stages (Optional)", isExpanded: $showAdvanced) {
                        VStack(spacing: 16) {
                            HStack {
                                Label("Deep Sleep", systemImage: "waveform")
                                    .foregroundStyle(.indigo)
                                Spacer()
                                Stepper("\(deepSleepMinutes) min", value: $deepSleepMinutes, in: 0...Int(durationHours * 60), step: 15)
                            }

                            HStack {
                                Label("REM Sleep", systemImage: "brain.head.profile")
                                    .foregroundStyle(.purple)
                                Spacer()
                                Stepper("\(remSleepMinutes) min", value: $remSleepMinutes, in: 0...Int(durationHours * 60), step: 15)
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveSleep() }
                    }
                    .disabled(isSaving || durationHours < 0.5)
                }
            }
            .loadingOverlay(isLoading: isSaving)
        }
    }

    private var qualityColor: Color {
        if quality >= 80 { return .green }
        if quality >= 50 { return .orange }
        return .red
    }

    private func saveSleep() async {
        isSaving = true
        error = nil

        let request = SleepLogRequest(
            durationHours: durationHours,
            quality: quality,
            bedTime: bedTime,
            wakeTime: wakeTime,
            deepSleepMinutes: deepSleepMinutes > 0 ? deepSleepMinutes : nil,
            remSleepMinutes: remSleepMinutes > 0 ? remSleepMinutes : nil
        )

        do {
            _ = try await APIService.shared.logSleep(request)
            HapticsManager.shared.success()
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            HapticsManager.shared.error()
        }

        isSaving = false
    }
}

#Preview {
    SleepView()
}
