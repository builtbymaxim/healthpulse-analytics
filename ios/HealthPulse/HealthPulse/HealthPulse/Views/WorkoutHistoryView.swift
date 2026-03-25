//
//  WorkoutHistoryView.swift
//  HealthPulse
//
//  Monthly calendar showing workout dots per day with PR highlighting.
//

import SwiftUI

struct WorkoutHistoryView: View {
    @State private var displayedMonth: Date = Date()
    @State private var calendarDays: [WorkoutCalendarDay] = []
    @State private var isLoading = false
    @State private var selectedDay: WorkoutCalendarDay? = nil

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdayLabels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: displayedMonth)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var calendarCells: [(day: Int?, dateStr: String?, data: WorkoutCalendarDay?)] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let firstDay = cal.date(from: comps) else { return [] }

        // Monday-first offset: iOS weekday 1=Sun → offset 6, 2=Mon → offset 0
        let weekday = cal.component(.weekday, from: firstDay)
        let offset = (weekday - 2 + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)?.count ?? 30
        let year = comps.year!
        let month = comps.month!

        var cells: [(day: Int?, dateStr: String?, data: WorkoutCalendarDay?)] = Array(
            repeating: (nil, nil, nil), count: offset
        )
        for day in 1...daysInMonth {
            let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
            let data = calendarDays.first { $0.date == dateStr }
            cells.append((day, dateStr, data))
        }
        return cells
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else {
                calendarGrid
            }
            legend
        }
        .padding(.horizontal)
        .task(id: monthKey) {
            await loadCalendar()
        }
        .sheet(item: $selectedDay) { day in
            CalendarDayDetailSheet(day: day)
                .presentationDetents([.height(220)])
        }
    }

    // MARK: - Sub-views

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = Calendar.current.date(
                        byAdding: .month, value: -1, to: displayedMonth
                    ) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.primary)
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = Calendar.current.date(
                        byAdding: .month, value: 1, to: displayedMonth
                    ) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppTheme.primary)
            }
            .disabled(monthKey >= currentMonthKey)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(calendarCells.enumerated()), id: \.offset) { index, cell in
                if let day = cell.day, let dateStr = cell.dateStr {
                    DayCell(day: day, dateStr: dateStr, data: cell.data) {
                        if let data = cell.data, data.workoutCount > 0 {
                            selectedDay = data
                            HapticsManager.shared.selection()
                        }
                    }
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            LegendDot(color: .blue, label: "Workout")
            LegendDot(color: .green, label: "Personal Record")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Data

    private var currentMonthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private func loadCalendar() async {
        isLoading = true
        defer { isLoading = false }
        if let days = try? await APIService.shared.getWorkoutCalendar(month: monthKey) {
            calendarDays = days
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let day: Int
    let dateStr: String
    let data: WorkoutCalendarDay?
    let onTap: () -> Void

    private var dotColor: Color? {
        guard let data, data.workoutCount > 0 else { return nil }
        return data.hasPr ? .green : .blue
    }

    private var isToday: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.subheadline)
                    .foregroundStyle(data?.workoutCount ?? 0 > 0 ? .primary : .secondary)
                Circle()
                    .fill(dotColor ?? Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? AppTheme.primary.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(data == nil || data?.workoutCount == 0)
    }
}

// MARK: - Legend Dot

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Day Detail Sheet

struct CalendarDayDetailSheet: View {
    let day: WorkoutCalendarDay

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day.date) else { return day.date }
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text(formattedDate)
                .font(.headline)

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(day.workoutCount)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primary)
                    Text(day.workoutCount == 1 ? "Workout" : "Workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if day.hasPr {
                    VStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("New PR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let rating = day.bestRating {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(i <= rating ? .yellow : .secondary)
                            }
                        }
                        Text("Best Rating")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .presentationDragIndicator(.visible)
    }
}
