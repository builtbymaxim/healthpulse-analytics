//
//  CalendarSyncService.swift
//  HealthPulse
//
//  Manages syncing training plan workouts to the iOS Calendar via EventKit.
//  Creates a dedicated "HealthPulse" calendar with events for the next 4 weeks.
//

import Foundation
import Combine
import EventKit
import UIKit

@MainActor
class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    // MARK: - Published State

    @Published var isAuthorized = false
    @Published var calendarSyncEnabled = false
    @Published var defaultWorkoutTime: Date

    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let calendarSyncEnabled = "calendar_sync_enabled"
        static let workoutHour = "calendar_workout_hour"
        static let workoutMinute = "calendar_workout_minute"
        static let hasSetDefaults = "calendar_has_set_defaults"
        static let healthPulseCalendarId = "calendar_healthpulse_id"
        static let lastSyncDate = "calendar_last_sync_date"
    }

    // MARK: - Init

    private init() {
        let cal = Calendar.current
        defaultWorkoutTime = cal.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        loadPreferences()
        checkAuthorizationStatus()
    }

    // MARK: - Preferences

    private func loadPreferences() {
        guard defaults.bool(forKey: Keys.hasSetDefaults) else { return }
        calendarSyncEnabled = defaults.bool(forKey: Keys.calendarSyncEnabled)

        let cal = Calendar.current
        let h = defaults.integer(forKey: Keys.workoutHour)
        let m = defaults.integer(forKey: Keys.workoutMinute)
        defaultWorkoutTime = cal.date(from: DateComponents(hour: h, minute: m)) ?? defaultWorkoutTime
    }

    func savePreferences() {
        let cal = Calendar.current
        defaults.set(true, forKey: Keys.hasSetDefaults)
        defaults.set(calendarSyncEnabled, forKey: Keys.calendarSyncEnabled)

        let tc = cal.dateComponents([.hour, .minute], from: defaultWorkoutTime)
        defaults.set(tc.hour ?? 7, forKey: Keys.workoutHour)
        defaults.set(tc.minute ?? 0, forKey: Keys.workoutMinute)
    }

    // MARK: - Authorization

    func requestAccess() async {
        if #available(iOS 17.0, *) {
            let granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
            isAuthorized = granted
        } else {
            let granted = (try? await eventStore.requestAccess(to: .event)) ?? false
            isAuthorized = granted
        }
    }

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
    }

    // MARK: - HealthPulse Calendar Management

    func getOrCreateHealthPulseCalendar() -> EKCalendar? {
        // Try stored identifier first
        if let storedId = defaults.string(forKey: Keys.healthPulseCalendarId),
           let existing = eventStore.calendar(withIdentifier: storedId) {
            return existing
        }

        // Search by title (identifier may have been lost)
        if let existing = eventStore.calendars(for: .event)
            .first(where: { $0.title == "HealthPulse" }) {
            defaults.set(existing.calendarIdentifier, forKey: Keys.healthPulseCalendarId)
            return existing
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "HealthPulse"
        calendar.cgColor = UIColor.systemGreen.cgColor

        // Prefer iCloud source, then local
        if let iCloud = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            calendar.source = iCloud
        } else if let local = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        } else {
            print("CalendarSync: No valid calendar source found")
            return nil
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            defaults.set(calendar.calendarIdentifier, forKey: Keys.healthPulseCalendarId)
            return calendar
        } catch {
            print("CalendarSync: Failed to create calendar: \(error)")
            return nil
        }
    }

    // MARK: - Sync

    func syncCalendar(schedule: [String: String]?, planName: String?) async {
        guard calendarSyncEnabled, isAuthorized else { return }
        guard let calendar = getOrCreateHealthPulseCalendar() else { return }

        // Remove existing future events
        removeAllHealthPulseEvents(from: calendar)

        // If no schedule, we're done (plan deactivated)
        guard let schedule = schedule, !schedule.isEmpty else { return }

        // Fetch workout details for exercise lists and durations
        let workoutDetails = await fetchWorkoutDetails()

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let timeComponents = cal.dateComponents([.hour, .minute], from: defaultWorkoutTime)

        for dayOffset in 0..<28 {
            guard let targetDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let iosWeekday = cal.component(.weekday, from: targetDate)
            let isoDay = iosWeekday == 1 ? 7 : iosWeekday - 1

            guard let workoutName = schedule[String(isoDay)] else { continue }

            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = workoutName

            // Start time from user preference
            var startComponents = cal.dateComponents([.year, .month, .day], from: targetDate)
            startComponents.hour = timeComponents.hour
            startComponents.minute = timeComponents.minute
            guard let startDate = cal.date(from: startComponents) else { continue }
            event.startDate = startDate

            // Duration from template or default 60 min
            let durationMinutes = workoutDetails[workoutName]?.estimatedMinutes ?? 60
            event.endDate = cal.date(byAdding: .minute, value: durationMinutes, to: startDate)

            // Notes with plan name and exercise list
            var notes = ""
            if let planName = planName {
                notes += "Training Plan: \(planName)\n\n"
            }
            if let exercises = workoutDetails[workoutName]?.exercises {
                notes += "Exercises:\n"
                for exercise in exercises {
                    var line = "- \(exercise.name)"
                    if let sets = exercise.sets, let reps = exercise.reps {
                        line += " (\(sets) x \(reps))"
                    }
                    notes += "\(line)\n"
                }
            }
            if !notes.isEmpty {
                event.notes = notes
            }

            event.addAlarm(EKAlarm(relativeOffset: -1800)) // 30 min before

            do {
                try eventStore.save(event, span: .thisEvent, commit: false)
            } catch {
                print("CalendarSync: Failed to save event \(workoutName): \(error)")
            }
        }

        do {
            try eventStore.commit()
            defaults.set(Date(), forKey: Keys.lastSyncDate)
        } catch {
            print("CalendarSync: Failed to commit events: \(error)")
        }
    }

    /// Re-sync if 7+ days since last sync (called on app foreground)
    func syncIfNeeded() async {
        guard calendarSyncEnabled, isAuthorized else { return }

        let lastSync = defaults.object(forKey: Keys.lastSyncDate) as? Date ?? .distantPast
        let daysSinceSync = Calendar.current.dateComponents([.day], from: lastSync, to: Date()).day ?? 999

        guard daysSinceSync >= 7 else { return }

        do {
            let plan = try await APIService.shared.getActiveTrainingPlan()
            await syncCalendar(schedule: plan?.schedule, planName: plan?.name)
        } catch {
            print("CalendarSync: syncIfNeeded failed: \(error)")
        }
    }

    // MARK: - Conflict Checking

    /// Check for calendar conflicts on training days at the proposed time.
    /// Returns [ISO day number: [conflicting event titles]]
    func checkConflicts(schedule: [String: String], durationMinutes: Int = 60) -> [Int: [String]] {
        guard isAuthorized else { return [:] }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let timeComponents = cal.dateComponents([.hour, .minute], from: defaultWorkoutTime)

        // Get HealthPulse calendar ID to exclude
        let hpCalendarId = defaults.string(forKey: Keys.healthPulseCalendarId)

        // Exclude HealthPulse calendar from conflict check
        let allCalendars = eventStore.calendars(for: .event).filter { $0.calendarIdentifier != hpCalendarId }

        var conflicts: [Int: [String]] = [:]

        for (dayStr, _) in schedule {
            guard let isoDay = Int(dayStr) else { continue }

            // Find the next occurrence of this weekday
            let iosWeekday = isoDay == 7 ? 1 : isoDay + 1

            // Search up to 7 days to find next occurrence
            for offset in 0..<7 {
                guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
                if cal.component(.weekday, from: date) == iosWeekday {
                    // Build time window
                    var startComponents = cal.dateComponents([.year, .month, .day], from: date)
                    startComponents.hour = timeComponents.hour
                    startComponents.minute = timeComponents.minute
                    guard let startDate = cal.date(from: startComponents),
                          let endDate = cal.date(byAdding: .minute, value: durationMinutes, to: startDate) else { break }

                    let predicate = eventStore.predicateForEvents(
                        withStart: startDate,
                        end: endDate,
                        calendars: allCalendars.isEmpty ? nil : allCalendars
                    )
                    let events = eventStore.events(matching: predicate)

                    if !events.isEmpty {
                        conflicts[isoDay] = events.map(\.title).compactMap { $0 }
                    }
                    break
                }
            }
        }

        return conflicts
    }

    // MARK: - Removal

    private func removeAllHealthPulseEvents(from calendar: EKCalendar) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 60, to: start) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        for event in events {
            try? eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try? eventStore.commit()
    }

    func removeAllEvents() {
        guard let calendar = getOrCreateHealthPulseCalendar() else { return }
        removeAllHealthPulseEvents(from: calendar)
    }

    func cleanupOnLogout() {
        if let storedId = defaults.string(forKey: Keys.healthPulseCalendarId),
           let calendar = eventStore.calendar(withIdentifier: storedId) {
            try? eventStore.removeCalendar(calendar, commit: true)
        }
        defaults.removeObject(forKey: Keys.healthPulseCalendarId)
        defaults.removeObject(forKey: Keys.lastSyncDate)
        calendarSyncEnabled = false
        savePreferences()
    }

    // MARK: - Helpers

    private func fetchWorkoutDetails() async -> [String: TemplateWorkout] {
        var details: [String: TemplateWorkout] = [:]
        do {
            let plan = try await APIService.shared.getActiveTrainingPlan()
            if let plan = plan {
                let templates = try await APIService.shared.getTrainingPlanTemplates()
                if let matching = templates.first(where: { $0.name == plan.name }),
                   let workouts = matching.workouts {
                    for workout in workouts {
                        details[workout.name] = workout
                    }
                }
            }
        } catch {
            print("CalendarSync: Failed to fetch workout details: \(error)")
        }
        return details
    }
}
