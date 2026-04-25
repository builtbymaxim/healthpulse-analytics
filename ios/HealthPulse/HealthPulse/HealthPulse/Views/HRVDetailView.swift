//
//  HRVDetailView.swift
//  HealthPulse
//
//  HRV historical trend summary

import SwiftUI
import Charts

struct HRVDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeriod: HealthKitService.ChartPeriod = .sevenDays
    @State private var isLoading = false
    @State private var selectedDate: Date?
    @State private var chartData: [HealthKitService.ChartDataPoint] = []
    @State private var chartOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // HEADER
                    VStack(alignment: .leading, spacing: 8) {
                        Text(periodLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latest")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("\(Int(currentHRV))ms")
                                    .font(.title2.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("\(Int(averageHRV))ms")
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
                    .padding()

                    // Zone legend
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hue: 0.11, saturation: 0.85, brightness: 0.9))
                            .frame(width: 8, height: 8)
                        Text("Healthy Zone: 40–100 ms")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(height: 250)
                    } else if !chartData.isEmpty {
                        hrvChart
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

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Min",
                            value: String(format: "%.0f", minHRV),
                            subtitle: "ms"
                        )
                        StatCard(
                            title: "Max",
                            value: String(format: "%.0f", maxHRV),
                            subtitle: "ms"
                        )
                        StatCard(
                            title: "Trend",
                            value: trendArrow
                        )
                        StatCard(
                            title: "Status",
                            value: hrvStatus.label,
                            subtitle: hrvStatus.icon
                        )
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(ThemedBackground())
            .navigationTitle("HRV Trend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadHRVData()
            }
            .onChange(of: selectedPeriod) {
                Task { await loadHRVData() }
            }
        }
    }

    private var hrvChart: some View {
        Chart {
            RectangleMark(yStart: .value("Low", 40), yEnd: .value("High", 100))
                .foregroundStyle(zoneColor.opacity(0.02))
                .zIndex(0)

            RuleMark(y: .value("Upper", 100))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(zoneColor.opacity(0.5))
                .zIndex(0)

            RuleMark(y: .value("Lower", 40))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(zoneColor.opacity(0.5))
                .zIndex(0)

            ForEach(displayData) { point in
                chartDataMarks(for: point)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...max(120, (chartData.map { $0.value }.max() ?? 100) * 1.1))
        .chartPlotStyle { plotArea in
            plotArea.background(AppTheme.surface1)
        }
        .chartXAxis {
            AxisMarks(values: xAxisValuesHRV()) { _ in
                AxisValueLabel(format: xAxisFormatHRV())
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
                    Text(isAveragedPeriod ? "~\(Int(selected.value)) ms" : "\(Int(selected.value)) ms")
                        .font(.caption.bold())
                    if isAveragedPeriod, let start = bucketStartDate(for: selected) {
                        Text("Avg \(dateLabel(start))–\(dateLabel(selected.date))")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text(dateLabel(selected.date))
                            .font(.caption2)
                    }
                    Text(hrvStatus.label)
                        .font(.caption)
                        .foregroundStyle(hrvStatus.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.top, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                chartOpacity = 1.0
            }
        }
    }

    private let zoneColor = Color(hue: 0.11, saturation: 0.85, brightness: 0.9)

    @ChartContentBuilder
    private func chartDataMarks(for point: HealthKitService.ChartDataPoint) -> some ChartContent {
        LineMark(x: .value("Date", point.date), y: .value("HRV", point.value))
            .foregroundStyle(AppTheme.primary.opacity(0.6))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.0))
            .zIndex(1)

        PointMark(x: .value("Date", point.date), y: .value("HRV", point.value))
            .foregroundStyle(AppTheme.primary)
            .symbolSize(isSelectedPoint(point) ? 140 : 80)
            .opacity(chartOpacity)
            .zIndex(2)
    }

    private var periodLabel: String {
        switch selectedPeriod {
        case .today:     return "Today"
        case .sevenDays: return "Last 7 Days"
        case .thirtyDays: return "Last 30 Days"
        }
    }

    private var displayData: [HealthKitService.ChartDataPoint] {
        guard selectedPeriod == .thirtyDays, chartData.count > 10 else { return chartData }
        let bucketSize = 5
        return stride(from: 0, to: chartData.count, by: bucketSize).compactMap { start in
            let chunk = Array(chartData[start..<min(start + bucketSize, chartData.count)])
            guard let lastDate = chunk.last?.date else { return nil }
            let avg = chunk.map { $0.value }.reduce(0, +) / Double(chunk.count)
            return HealthKitService.ChartDataPoint(date: lastDate, value: avg)
        }
    }

    private var currentHRV: Double {
        chartData.last?.value ?? 0
    }

    private var averageHRV: Double {
        chartData.isEmpty ? 0 : chartData.map { $0.value }.reduce(0, +) / Double(chartData.count)
    }

    private var minHRV: Double {
        chartData.map { $0.value }.min() ?? 0
    }

    private var maxHRV: Double {
        chartData.map { $0.value }.max() ?? 0
    }

    private var hrvStatus: (label: String, icon: String, color: Color) {
        let current = currentHRV
        if current >= 100 {
            return ("Excellent", "heart.fill", .green)
        } else if current >= 40 {
            return ("Normal", "heart.fill", AppTheme.primary)
        } else {
            return ("Low", "heart.fill", .orange)
        }
    }

    private var trendArrow: String {
        if chartData.count < 2 { return "→" }
        let recentHalf = chartData.suffix(chartData.count / 2).map { $0.value }.reduce(0, +) / Double(max(chartData.count / 2, 1))
        let olderHalf = chartData.prefix(chartData.count / 2).map { $0.value }.reduce(0, +) / Double(max(chartData.count / 2, 1))
        if recentHalf > olderHalf + 3 { return "↑" }
        if recentHalf < olderHalf - 3 { return "↓" }
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

    private var isAveragedPeriod: Bool {
        selectedPeriod == .thirtyDays
    }

    private func bucketStartDate(for point: HealthKitService.ChartDataPoint) -> Date? {
        guard selectedPeriod == .thirtyDays else { return nil }
        guard let idx = displayData.firstIndex(where: { $0.id == point.id }) else { return nil }
        let startIdx = idx * 5
        return startIdx < chartData.count ? chartData[startIdx].date : nil
    }

    private func isSelectedPoint(_ point: HealthKitService.ChartDataPoint) -> Bool {
        selectedPoint?.id == point.id
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func xAxisValuesHRV() -> [Date] {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .today:
            return (0..<24).filter { $0 % 4 == 0 }.compactMap { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
            }
        case .sevenDays:
            let today = calendar.startOfDay(for: Date())
            return (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: -(6 - offset), to: today)
            }
        case .thirtyDays:
            guard !displayData.isEmpty else { return [] }
            let stride = max(1, displayData.count / 5)
            return displayData.enumerated().compactMap { i, point in
                i % stride == 0 ? point.date : nil
            }
        }
    }

    private func xAxisFormatHRV() -> Date.FormatStyle {
        switch selectedPeriod {
        case .today:
            return .dateTime.hour(.defaultDigits(amPM: .omitted))
        case .sevenDays:
            return .dateTime.weekday(.abbreviated)
        case .thirtyDays:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private func loadHRVData() async {
        isLoading = true
        let data = await HealthKitService.shared.fetchHRVHistory(period: selectedPeriod)
        chartData = data
        chartOpacity = 0
        isLoading = false
    }
}

#Preview {
    HRVDetailView()
}
