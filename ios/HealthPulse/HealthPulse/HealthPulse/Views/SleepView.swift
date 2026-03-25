//
//  SleepView.swift
//  HealthPulse
//
//  Sleep tracking dashboard with history and analytics
//

import SwiftUI
import Charts

struct SleepView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var tabRouter: TabRouter
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
                    } else if summary == nil && history.isEmpty
                                && healthKitService.lastSleepHours == nil
                                && healthKitService.sleepStageHours == nil {
                        // No sleep data from HealthKit or backend yet
                        EmptyStateView(
                            icon: "moon.zzz",
                            title: "No Sleep Data Yet",
                            message: "Log your first night's sleep to start tracking your rest patterns.",
                            actionTitle: "Log Sleep",
                            action: { showingLogSheet = true }
                        )
                    } else {
                        // Last Night + Sleep Stages — prefer HealthKit, fall back to backend
                        if healthKitService.sleepStageHours != nil || healthKitService.lastSleepHours != nil {
                            LastNightHKCard(
                                totalHours: healthKitService.lastSleepHours ?? 0,
                                stages: healthKitService.sleepStageHours
                            )
                            .staggeredAnimation(index: 0)
                        } else if let summary = summary {
                            TodaySleepCard(summary: summary)
                                .staggeredAnimation(index: 0)
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
            .background(ThemedBackground())
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
            .onChange(of: tabRouter.selectedTab) { _, newTab in
                if newTab == .sleep {
                    Task { await loadData() }
                }
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
        // Only show skeleton loading on initial load, not during pull-to-refresh
        if summary == nil && history.isEmpty {
            isLoading = true
        }
        error = nil
        APIService.shared.invalidateCache(matching: "/sleep")

        // Refresh HealthKit in parallel with backend calls
        async let hkRefresh: Void = healthKitService.refreshTodayData()

        do {
            async let summaryTask = APIService.shared.getSleepSummary()
            async let historyTask = APIService.shared.getSleepHistory(days: selectedPeriod)
            async let analyticsTask = APIService.shared.getSleepAnalytics(days: 30)

            let (s, h, a) = try await (summaryTask, historyTask, analyticsTask)
            await hkRefresh
            summary = s
            history = h
            analytics = a
        } catch {
            await hkRefresh
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Last Night HealthKit Card

struct LastNightHKCard: View {
    let totalHours: Double
    let stages: SleepStageHours?

    private var formattedTotal: String {
        guard totalHours > 0 else { return "No Data" }
        let h = Int(totalHours)
        let m = Int((totalHours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Last Night", systemImage: "moon.zzz.fill")
                    .font(.headline)
                Spacer()
                Text(formattedTotal)
                    .font(.title3.bold())
                    .foregroundStyle(totalHours > 0 ? Color.purple : Color.secondary)
                    .contentTransition(.numericText())
            }

            if totalHours == 0 {
                Text("No Apple Watch sleep data for last night.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let stages = stages, stages.total > 0 {
                // Horizontal stage bar: Deep / REM / Light (Core mapped to Light)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if stages.deep > 0 {
                            Rectangle()
                                .fill(SleepStage.deep.color)
                                .frame(width: geo.size.width * (stages.deep / stages.total))
                        }
                        if stages.rem > 0 {
                            Rectangle()
                                .fill(SleepStage.rem.color)
                                .frame(width: geo.size.width * (stages.rem / stages.total))
                        }
                        if stages.core > 0 {
                            Rectangle()
                                .fill(SleepStage.light.color)
                                .frame(width: geo.size.width * (stages.core / stages.total))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 12)

                HStack(spacing: 16) {
                    if stages.deep > 0  { stageLegend(.deep,  hours: stages.deep) }
                    if stages.rem > 0   { stageLegend(.rem,   hours: stages.rem) }
                    if stages.core > 0  { stageLegend(.light, hours: stages.core) }
                }
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }

    private func stageLegend(_ stage: SleepStage, hours: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stage.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(stage.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatHours(hours))
                    .font(.subheadline.bold())
            }
        }
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Today's Sleep Card

struct TodaySleepCard: View {
    let summary: SleepSummary

    var body: some View {
        GlassCard {
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
                                .contentTransition(.numericText())
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
        }
        .elevatedShadow()
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
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
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
                        let pct = summary.durationHours > 0 ? item.hours / summary.durationHours : 0
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
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
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
                    y: .value("Hours", entry.durationHours),
                    width: .fixed(20)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primary.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .clipped()
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
            .chartYScale(domain: 0...max(12.0, (entries.map(\.durationHours).max() ?? 0) + 1.0))

            // Target line note
            HStack {
                Rectangle()
                    .fill(AppTheme.primary.opacity(0.4))
                    .frame(width: 20, height: 2)
                Text("7-9h target range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
    }
}

// MARK: - Sleep Metric Type

enum SleepMetricType: String, Identifiable {
    case avgDuration, avgScore, sleepDebt, consistency
    var id: String { rawValue }

    var title: String {
        switch self {
        case .avgDuration:  return "Avg Duration"
        case .avgScore:     return "Avg Score"
        case .sleepDebt:    return "Sleep Debt"
        case .consistency:  return "Consistency"
        }
    }

    var icon: String {
        switch self {
        case .avgDuration:  return "clock.fill"
        case .avgScore:     return "star.fill"
        case .sleepDebt:    return "exclamationmark.triangle.fill"
        case .consistency:  return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .avgDuration:  return AppTheme.primary
        case .avgScore:     return .yellow
        case .sleepDebt:    return .orange
        case .consistency:  return AppTheme.primary
        }
    }

    var explanation: String {
        switch self {
        case .avgDuration:
            return "The average number of hours you slept per night over the past 30 days. HealthPulse calculates this from your logged or HealthKit-synced sessions. Adults need 7–9 hours for full physical and cognitive recovery — consistent shortfalls suppress immune function and reduce athletic performance."
        case .avgScore:
            return "A composite 0–100 score combining duration, self-reported quality, and sleep stage ratios. HealthPulse weights deep and REM sleep more heavily, as these stages drive muscle repair and memory consolidation. A score above 75 indicates restorative sleep."
        case .sleepDebt:
            return "The cumulative hours of sleep lost relative to your 8-hour daily target over the past 30 days. Sleep debt compounds: each missed hour raises cortisol levels and reduces next-day HRV. HealthPulse uses this to adjust your recovery score and training recommendations."
        case .consistency:
            return "How stable your sleep and wake times are, measured as variance across the past 30 days. Consistent timing anchors your circadian rhythm, which regulates hormones like melatonin and cortisol. Even one hour of daily variance can reduce sleep quality by up to 20%."
        }
    }
}

// MARK: - Sleep Analytics Card

struct SleepAnalyticsCard: View {
    let analytics: SleepAnalytics
    @State private var selectedMetric: SleepMetricType?

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
                Button { selectedMetric = .avgDuration } label: {
                    AnalyticTile(
                        title: "Avg Duration",
                        value: analytics.formattedAvgDuration,
                        icon: "clock.fill",
                        color: AppTheme.primary
                    )
                }
                .buttonStyle(.plain)

                Button { selectedMetric = .avgScore } label: {
                    AnalyticTile(
                        title: "Avg Score",
                        value: "\(Int(analytics.avgSleepScore))",
                        icon: "star.fill",
                        color: .yellow
                    )
                }
                .buttonStyle(.plain)

                Button { selectedMetric = .sleepDebt } label: {
                    AnalyticTile(
                        title: "Sleep Debt",
                        value: String(format: "%.1fh", analytics.totalSleepDebtHours),
                        icon: "exclamationmark.triangle.fill",
                        color: analytics.totalSleepDebtHours > 10 ? .red : .orange
                    )
                }
                .buttonStyle(.plain)

                Button { selectedMetric = .consistency } label: {
                    AnalyticTile(
                        title: "Consistency",
                        value: "\(Int(analytics.consistencyScore))%",
                        icon: "checkmark.seal.fill",
                        color: AppTheme.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .cardShadow()
        .sheet(item: $selectedMetric) { metric in
            SleepMetricDetailSheet(metric: metric)
        }
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
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sleep Metric Detail Sheet

struct SleepMetricDetailSheet: View {
    let metric: SleepMetricType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(metric.color.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: metric.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(metric.color)
                    }

                    Text(metric.explanation)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Sleep Log Sheet

struct SleepLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: () async -> Void

    // Default: bedtime yesterday at 11pm, wake time now
    @State private var bedTime: Date = {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) ?? yesterday
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
        .environmentObject(HealthKitService.shared)
}
