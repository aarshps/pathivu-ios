import Foundation
import UserNotifications

/// Schedules the single daily "habits still to do" reminder using
/// UNUserNotificationCenter.
///
/// **Why scheduled-local, not a background query:** the Android app runs a
/// chained WorkManager worker that, at the reminder time, queries Firestore for
/// the habits still pending and posts a bullet-list summary. iOS background
/// execution is far too restricted to make that network round-trip on a
/// schedule. So instead — exactly like the Varisankya iOS sibling — every time
/// the app is foregrounded (or habits change) we **re-schedule** a single local
/// notification for the next reminder time, with the body computed from the
/// habits currently due-and-not-done. The app foregrounding frequently keeps
/// the summary fresh without any push dependency.
enum NotificationScheduler {

    static let categoryIdentifier = "com.hora.pathivu.habitReminder"
    private static let requestIdentifier = "pathivu.daily.reminder"

    /// Configures the (action-less) notification category. Android deliberately
    /// removed the "Mark all done" action — tapping anywhere just opens the app.
    static func configureCategories() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func clearAllScheduled() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
    }

    /// Re-schedules the daily reminder. `habits` should be the user's active set.
    /// If reminders are off, or nothing is pending for the target day, clears any
    /// pending reminder instead.
    static func reschedule(for habits: [Habit]) async {
        let prefs = Preferences.shared
        clearAllScheduled()
        guard prefs.remindersEnabled else { return }

        let hour = prefs.notificationHour
        let minute = prefs.notificationMinute
        let cal = Calendar(identifier: .gregorian)
        let now = Date()

        // Next fire = today at hour:minute if still ahead, else tomorrow.
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard var fire = cal.date(from: comps) else { return }
        let firesTomorrow = fire <= now
        if firesTomorrow { fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire }

        // Which habits are "pending" for the day the reminder lands on. If the
        // reminder is still ahead today, use today's not-yet-done set. If it has
        // already passed today, the reminder lands tomorrow, so use whatever is
        // scheduled for tomorrow (done-state unknown, assume none done).
        let active = habits.filter { !$0.archived && !$0.negative }
        let pending: [Habit]
        if firesTomorrow {
            let tomorrow = HabitStats.addDays(HabitStats.today(), 1)
            pending = active.filter { HabitStats.isScheduledOn($0, tomorrow) }
        } else {
            pending = active.filter { HabitStats.isDueToday($0) && !HabitStats.isDoneToday($0) }
        }
        guard !pending.isEmpty else { return }

        let count = pending.count
        let content = UNMutableNotificationContent()
        content.title = count == 1 ? "1 habit to go today" : "\(count) habits to go today"
        content.body = pending.map { "•  \($0.name)" }.joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = "habits"

        let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
        AppAnalytics.notificationWorkerScheduled()
    }

    /// Settings → "Send test notification".
    static func postTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Pathivu — test notification"
        content.body = "If you can see this, reminders are working. 🌱"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pathivu-test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        AppAnalytics.notificationTestSent()
    }
}
