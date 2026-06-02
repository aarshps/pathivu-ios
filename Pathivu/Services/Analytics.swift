import Foundation
import FirebaseAnalytics

/// Thin wrapper around FirebaseAnalytics. Mirrors the Android `Analytics` surface
/// so dashboards stay readable across platforms.
///
/// **Invariant:** scalar params only — never log habit names, document IDs, or
/// other high-cardinality text (Firebase Analytics caps distinct text values per
/// param at ~40).
enum AppAnalytics {

    private static func log(_ event: String, _ params: [String: Any] = [:]) {
        Analytics.logEvent(event, parameters: params.isEmpty ? nil : params)
    }

    // MARK: Habit flows
    static func habitAddOpen() { log("habit_add_open") }
    static func habitEditOpen() { log("habit_edit_open") }
    static func habitSave(isNew: Bool, schedule: String) {
        log("habit_save", ["is_new": isNew, "schedule": schedule])
    }
    static func habitToggle(done: Bool) { log("habit_toggle", ["done": done]) }
    static func habitToggleBackfill() { log("habit_toggle_backfill") }
    static func habitArchive() { log("habit_archive") }
    static func habitRestore() { log("habit_restore") }
    static func habitDelete() { log("habit_delete") }
    static func habitReorder() { log("habit_reorder") }

    // MARK: Notifications
    static func notificationWorkerScheduled() { log("notification_worker_scheduled") }
    static func notificationWorkerRun(success: Bool, signedIn: Bool, habitsDue: Int, notificationsPosted: Int) {
        log("notification_worker_run", [
            "success": success,
            "signed_in": signedIn,
            "habits_due": habitsDue,
            "notifications_posted": notificationsPosted
        ])
    }
    static func notificationPosted(pending: Int) { log("notification_posted", ["pending": pending]) }
    static func notificationTap() { log("notification_tap") }
    static func notificationDismiss() { log("notification_dismiss") }
    static func notificationTestSent() { log("notification_test_sent") }

    // MARK: Navigation
    static func homeRefreshPull() { log("home_refresh_pull") }
    static func screenStatsOpen() { log("screen_stats_open") }
    static func screenSettingsOpen() { log("screen_settings_open") }
    static func screenAboutOpen() { log("screen_about_open") }
    static func screenDayEditorOpen() { log("screen_day_editor_open") }
    static func screenArchivedOpen() { log("screen_archived_open") }

    // MARK: Settings
    static func settingFontChange(_ font: String) { log("setting_font_change", ["font": font]) }
    static func settingHapticsToggle(_ enabled: Bool) { log("setting_haptics_toggle", ["enabled": enabled]) }
    static func settingAppLockToggle(_ enabled: Bool) { log("setting_app_lock_toggle", ["enabled": enabled]) }
    static func settingRemindersToggle(_ enabled: Bool) { log("setting_reminders_toggle", ["enabled": enabled]) }
    static func settingReminderTimeChange() { log("setting_reminder_time_change") }
    static func settingDayStartChange(_ offset: Int) { log("setting_day_start_change", ["offset": offset]) }
    static func settingWeekStartChange(_ iso: Int) { log("setting_week_start_change", ["iso": iso]) }

    // MARK: Auth
    static func authSignIn(provider: String) { log("auth_sign_in", ["provider": provider]) }
    static func authSignOut() { log("auth_sign_out") }
}
