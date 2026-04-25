//
//  StepDetailView.swift
//  HealthPulse
//
//  Step history with hourly/daily/monthly breakdown

import SwiftUI
import Charts

struct StepDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var healthKit = HealthKitService.shared
    @State private var selectedPeriod: HealthKitService.ChartPeriod = .today
    @State private var stepData: [HealthKitService.ChartDataPoint] = []
    @State private var isLoading = false
    @State private var selectedDate: Date?
    @State private var chartScale: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // HEADER — total/avg stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text(periodLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(Int(totalSteps).formatted())
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(selectedPeriod == .today ? "Hourly Avg" : "Daily Avg")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(Int(averageSteps).formatted())
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Period selector
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Today (Hourly)").tag(HealthKitService.ChartPeriod.today)
                        Text("7 Days").tag(HealthKitService.ChartPeriod.sevenDays)
                        Text("30 Days").tag(HealthKitService.ChartPeriod.thirtyDays)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                    } else if !stepData.isEmpty {
                        stepChart
                            .frame(height: 250)
                            .padding()
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }

                    // Goal progress
                    if selectedPeriod == .today {
                        goalProgressView(label: "Daily Goal", current: totalSteps, goal: 10_000)
                    } else {
                        goalProgressView(label: "Avg vs Goal", current: averageSteps, goal: 10_000)
                    }

                    // Stats grid (period-specific)
                    Group {
                        if selectedPeriod == .today {
                            todayStatsGrid
                        } else {
                            periodStatsGrid
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationTitle("Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadStepData()
            }
            .onChange(of: selectedPeriod) {
                Task { await loadStepData() }
            }
        }
    }

    private var stepChart: some View {
        Chart(displayData) { point in
            BarMark(
                x: .value("Date", point.date, unit: bucketUnit),
                y: .value("Steps", point.value)
            )
            .foregroundStyle(
                isSelectedPoint(point) ? AppTheme.accent
                : (selectedPeriod != .today && point.value >= 10_000) ? AppTheme.primary
                : AppTheme.primary.opacity(0.45)
            )
            .cornerRadius(4)
            .opacity(chartScale)
        }
        .chartXSelection(value: $selectedDate)
        .chartPlotStyle { plotArea in
            plotArea.background(AppTheme.surface1)
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues()) { _ in
                AxisValueLabel(format: xAxisFormat())
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel()
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .overlay(alignment: .top) {
            if let selected = selectedPoint {
                VStack(spacing: 2) {
                    if selectedPeriod == .thirtyDays, let start = bucketStartDate(for: selected) {
                        Text("Avg \(dateFormatted(start, format: "dd.MM"))–\(dateFormatted(selected.date, format: "dd.MM"))")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(selectedPeriod == .thirtyDays ? "~\(Int(selected.value).formatted())" : Int(selected.value).formatted())
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.surface2)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15)) {
                chartScale = 1.0
            }
        }
    }

    private var displayData: [HealthKitService.ChartDataPoint] {
        guard selectedPeriod == .thirtyDays, stepData.count > 10 else { return stepData }
        let bucketSize = 5
        return stride(from: 0, to: stepData.count, by: bucketSize).compactMap { start in
            let chunk = Array(stepData[start..<min(start + bucketSize, stepData.count)])
            guard let lastDate = chunk.last?.date else { return nil }
            let avg = chunk.map { $0.value }.reduce(0, +) / Double(chunk.count)
            return HealthKitService.ChartDataPoint(date: lastDate, value: avg)
        }
    }

    private var bucketUnit: Calendar.Component {
        selectedPeriod == .today ? .hour : .day
    }

    private var periodLabel: String {
        switch selectedPeriod {
        case .today: return "Today"
        case .sevenDays: return "Last 7 Days"
        case .thirtyDays: return "Last 30 Days"
        }
    }

    private func xAxisValues() -> [Date] {
        guard !stepData.isEmpty else { return [] }

        switch selectedPeriod {
        case .today:
            // Every 4 hours
            let calendar = Calendar.current
            var values: [Date] = []
            for hour in stride(from: 0, to: 24, by: 4) {
                if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                    values.append(date)
                }
            }
            return values
        case .sevenDays:
            // Every day
            return stepData.map { $0.date }
        case .thirtyDays:
            // Every 7 days
            return stepData.enumerated().compactMap { i, point in
                i % 7 == 0 ? point.date : nil
            }
        }
    }

    private func xAxisFormat() -> Date.FormatStyle {
        switch selectedPeriod {
        case .today:
            return .dateTime.hour(.defaultDigits(amPM: .omitted))
        case .sevenDays:
            return .dateTime.weekday(.abbreviated)
        case .thirtyDays:
            return .dateTime.month(.abbreviated).day()
        }
    }

    @ViewBuilder
    private func goalProgressView(label: String, current: Double, goal: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(String(format: "%.0f / %.0f", current, goal))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.surface1)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.primary)
                        .frame(width: geo.size.width * CGFloat(min(current / goal, 1)))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var todayStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Peak Hour",
                value: String(format: "%.0f", peakHourSteps),
                subtitle: peakHourLabel
            )
            StatCard(
                title: "Active Hours",
                value: String(activeHours),
                subtitle: "hours >100 steps"
            )
            StatCard(
                title: "Hourly Avg",
                value: String(format: "%.0f", averageSteps)
            )
            StatCard(
                title: "Goal %",
                value: String(format: "%.0f%%", min(totalSteps / 10_000 * 100, 100))
            )
        }
    }

    @ViewBuilder
    private var periodStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Best Day",
                value: String(format: "%.0f", bestDaySteps),
                subtitle: bestDayLabel
            )
            StatCard(
                title: "Hit Goal",
                value: "\(daysHittingGoal) / \(periodLength)",
                subtitle: "days ≥10k"
            )
            StatCard(
                title: "Daily Avg",
                value: String(format: "%.0f", averageSteps)
            )
            StatCard(
                title: "Trend",
                value: trendArrow
            )
        }
    }

    private var totalSteps: Double {
        stepData.reduce(0) { $0 + $1.value }
    }

    private var averageSteps: Double {
        stepData.isEmpty ? 0 : totalSteps / Double(stepData.count)
    }

    private var bestDaySteps: Double {
        stepData.map { $0.value }.max() ?? 0
    }

    private var peakHourSteps: Double {
        stepData.map { $0.value }.max() ?? 0
    }

    private var activeHours: Int {
        stepData.filter { $0.value > 100 }.count
    }

    private var daysHittingGoal: Int {
        stepData.filter { $0.value >= 10_000 }.count
    }

    private var periodLength: Int {
        stepData.count
    }

    private var bestDayLabel: String {
        if let best = stepData.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.dateFormat = selectedPeriod == .today ? "HH:mm" : "EEE"
            return formatter.string(from: best.date)
        }
        return "—"
    }

    private var peakHourLabel: String {
        if let peak = stepData.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:00"
            return formatter.string(from: peak.date)
        }
        return "—"
    }

    private var trendArrow: String {
        if stepData.count < 2 { return "→" }
        let recentHalf = stepData.suffix(stepData.count / 2).map { $0.value }.reduce(0, +) / Double(max(stepData.count / 2, 1))
        let olderHalf = stepData.prefix(stepData.count / 2).map { $0.value }.reduce(0, +) / Double(max(stepData.count / 2, 1))
        if recentHalf > olderHalf + 500 { return "↑" }
        if recentHalf < olderHalf - 500 { return "↓" }
        return "→"
    }

    private var selectedPoint: HealthKitService.ChartDataPoint? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        return displayData.first { point in
            if selectedPeriod == .today {
                return calendar.component(.hour, from: point.date) == calendar.component(.hour, from: selectedDate)
            } else {
                return calendar.isDate(point.date, inSameDayAs: selectedDate)
            }
        }
    }

    private func bucketStartDate(for point: HealthKitService.ChartDataPoint) -> Date? {
        guard selectedPeriod == .thirtyDays else { return nil }
        guard let idx = displayData.firstIndex(where: { $0.id == point.id }) else { return nil }
        let startIdx = idx * 5
        return startIdx < stepData.count ? stepData[startIdx].date : nil
    }

    private func isSelectedPoint(_ point: HealthKitService.ChartDataPoint) -> Bool {
        selectedPoint?.id == point.id
    }

    private func loadStepData() async {
        isLoading = true
        stepData = await healthKit.fetchStepHistory(period: selectedPeriod)
        chartScale = 0
        isLoading = false
    }

    private func dateFormatted(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?

    init(title: String, value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StepDetailView()
}
