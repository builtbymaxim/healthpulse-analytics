//
//  NotificationService.swift
//  HealthPulse
//
//  Manages local notifications for nutrition reminders, workout reminders,
//  and weekly performance reviews.
//

import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var mealRemindersEnabled = true
    @Published var workoutReminderEnabled = true
    @Published var weeklyReviewEnabled = true
    @Published var monthlyReviewEnabled = true

    @Published var breakfastTime: Date
    @Published var lunchTime: Date
    @Published var dinnerTime: Date

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    // UserDefaults keys
    private enum Keys {
        static let mealReminders = "notif_meal_reminders"
        static let workoutReminder = "notif_workout_reminder"
        static let weeklyReview = "notif_weekly_review"
        static let monthlyReview = "notif_monthly_review"
        static let breakfastHour = "notif_breakfast_hour"
        static let breakfastMinute = "notif_breakfast_minute"
        static let lunchHour = "notif_lunch_hour"
        static let lunchMinute = "notif_lunch_minute"
        static let dinnerHour = "notif_dinner_hour"
        static let dinnerMinute = "notif_dinner_minute"
        static let hasSetDefaults = "notif_has_set_defaults"
    }

    private init() {
        // Set default times before calling super
        let cal = Calendar.current
        breakfastTime = cal.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        lunchTime = cal.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
        dinnerTime = cal.date(from: DateComponents(hour: 19, minute: 30)) ?? Date()

        loadPreferences()
    }

    private func loadPreferences() {
        guard defaults.bool(forKey: Keys.hasSetDefaults) else {
            // First launch — keep published defaults
            return
        }

        mealRemindersEnabled = defaults.bool(forKey: Keys.mealReminders)
        workoutReminderEnabled = defaults.bool(forKey: Keys.workoutReminder)
        weeklyReviewEnabled = defaults.bool(forKey: Keys.weeklyReview)
        monthlyReviewEnabled = defaults.bool(forKey: Keys.monthlyReview)

        let cal = Calendar.current
        let bh = defaults.integer(forKey: Keys.breakfastHour)
        let bm = defaults.integer(forKey: Keys.breakfastMinute)
        breakfastTime = cal.date(from: DateComponents(hour: bh, minute: bm)) ?? breakfastTime

        let lh = defaults.integer(forKey: Keys.lunchHour)
        let lm = defaults.integer(forKey: Keys.lunchMinute)
        lunchTime = cal.date(from: DateComponents(hour: lh, minute: lm)) ?? lunchTime

        let dh = defaults.integer(forKey: Keys.dinnerHour)
        let dm = defaults.integer(forKey: Keys.dinnerMinute)
        dinnerTime = cal.date(from: DateComponents(hour: dh, minute: dm)) ?? dinnerTime
    }

    func savePreferences() {
        let cal = Calendar.current

        defaults.set(true, forKey: Keys.hasSetDefaults)
        defaults.set(mealRemindersEnabled, forKey: Keys.mealReminders)
        defaults.set(workoutReminderEnabled, forKey: Keys.workoutReminder)
        defaults.set(weeklyReviewEnabled, forKey: Keys.weeklyReview)
        defaults.set(monthlyReviewEnabled, forKey: Keys.monthlyReview)

        let bc = cal.dateComponents([.hour, .minute], from: breakfastTime)
        defaults.set(bc.hour ?? 9, forKey: Keys.breakfastHour)
        defaults.set(bc.minute ?? 0, forKey: Keys.breakfastMinute)

        let lc = cal.dateComponents([.hour, .minute], from: lunchTime)
        defaults.set(lc.hour ?? 13, forKey: Keys.lunchHour)
        defaults.set(lc.minute ?? 0, forKey: Keys.lunchMinute)

        let dc = cal.dateComponents([.hour, .minute], from: dinnerTime)
        defaults.set(dc.hour ?? 19, forKey: Keys.dinnerHour)
        defaults.set(dc.minute ?? 30, forKey: Keys.dinnerMinute)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule All Notifications

    func scheduleAllNotifications() async {
        await checkAuthorizationStatus()
        guard isAuthorized else { return }

        // Clear existing before rescheduling
        center.removeAllPendingNotificationRequests()

        if mealRemindersEnabled { scheduleMealReminders() }
        if workoutReminderEnabled { await scheduleWorkoutReminder() }
        if weeklyReviewEnabled { scheduleWeeklyReview() }
        if monthlyReviewEnabled { scheduleMonthlyReview() }
    }

    // MARK: - Meal / Nutrition Reminders

    func scheduleMealReminders() {
        let cal = Calendar.current
        let bc = cal.dateComponents([.hour, .minute], from: breakfastTime)
        let lc = cal.dateComponents([.hour, .minute], from: lunchTime)
        let dc = cal.dateComponents([.hour, .minute], from: dinnerTime)

        let meals: [(id: String, title: String, hour: Int, minute: Int)] = [
            ("meal_breakfast", "Log Breakfast", bc.hour ?? 9, bc.minute ?? 0),
            ("meal_lunch", "Log Lunch", lc.hour ?? 13, lc.minute ?? 0),
            ("meal_dinner", "Log Dinner", dc.hour ?? 19, dc.minute ?? 30),
        ]

        for meal in meals {
            let content = UNMutableNotificationContent()
            content.title = meal.title
            content.body = "Don't forget to track your meal in HealthPulse."
            content.sound = .default
            content.categoryIdentifier = "NUTRITION_REMINDER"

            var dateComponents = DateComponents()
            dateComponents.hour = meal.hour
            dateComponents.minute = meal.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: meal.id, content: content, trigger: trigger)

            center.add(request)
        }
    }

    // MARK: - Workout Day Reminder

    func scheduleWorkoutReminder() async {
        // Fetch today's workout plan to know which days have workouts
        do {
            let todayWorkout = try await APIService.shared.getTodaysWorkout()

            // Remove old workout reminders
            center.removePendingNotificationRequests(withIdentifiers: ["workout_daily"])

            if todayWorkout.hasPlan && !todayWorkout.isRestDay, let workoutName = todayWorkout.workoutName {
                let content = UNMutableNotificationContent()
                content.title = "Workout Day"
                content.body = "Today's workout: \(workoutName). Let's get it!"
                content.sound = .default
                content.categoryIdentifier = "WORKOUT_REMINDER"

                var dateComponents = DateComponents()
                dateComponents.hour = 8
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let request = UNNotificationRequest(identifier: "workout_daily", content: content, trigger: trigger)

                center.add(request)
            }
        } catch {
            // Fallback: generic workout reminder every day at 8am
            let content = UNMutableNotificationContent()
            content.title = "Ready to Train?"
            content.body = "Check your workout plan for today."
            content.sound = .default
            content.categoryIdentifier = "WORKOUT_REMINDER"

            var dateComponents = DateComponents()
            dateComponents.hour = 8
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "workout_daily", content: content, trigger: trigger)

            center.add(request)
        }
    }

    // MARK: - Weekly Review

    func scheduleWeeklyReview() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Review"
        content.body = "Your weekly performance summary is ready. See how you did!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REVIEW"

        // Sunday at 6pm
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_review", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Monthly Review

    func scheduleMonthlyReview() {
        let content = UNMutableNotificationContent()
        content.title = "Monthly Progress"
        content.body = "Check your monthly fitness progress and trends!"
        content.sound = .default
        content.categoryIdentifier = "MONTHLY_REVIEW"

        // 1st of each month at 10am
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly_review", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Management

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
