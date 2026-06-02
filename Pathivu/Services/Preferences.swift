import Foundation
import SwiftUI

/// Mirrors Android `PreferenceHelper`, storing user preferences in UserDefaults.
/// Exposes an `@Observable` wrapper so SwiftUI views auto-refresh on changes.
///
/// Two of these settings also configure the pure-stat engine: `dayStartHour`
/// and `weekStartDay` are pushed into `HabitStats` (which holds them as static
/// config) whenever they change or the app starts — see `syncStatsConfig()`.
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let hapticsEnabled = "haptics_enabled"
        static let useGoogleFont = "use_google_font"
        static let biometricEnabled = "biometric_enabled"
        static let remindersEnabled = "reminders_enabled"
        static let notifHour = "notification_hour"
        static let notifMinute = "notification_minute"
        static let dayStartHour = "day_start_hour"
        static let weekStart = "week_start_day"
        static let appearance = "appearance_mode"
        static let lastActiveDay = "last_active_day"
        static let onboardedNotifications = "notif_perm_requested"
    }

    init() {
        syncStatsConfig()
    }

    /// Push `dayStartHour` / `weekStartDay` into the stat engine. Call at startup
    /// and after either changes.
    func syncStatsConfig() {
        HabitStats.dayStartHour = dayStartHour
        HabitStats.weekStartDay = weekStartDay
    }

    // MARK: Haptics
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    // MARK: Font (system vs rounded "Google Sans Flex"-equivalent)
    var useGoogleFont: Bool {
        get { defaults.object(forKey: Key.useGoogleFont) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.useGoogleFont) }
    }

    // MARK: Biometric (Face ID / Touch ID)
    var biometricEnabled: Bool {
        get { defaults.bool(forKey: Key.biometricEnabled) }
        set { defaults.set(newValue, forKey: Key.biometricEnabled) }
    }

    // MARK: Daily reminder
    var remindersEnabled: Bool {
        get { defaults.object(forKey: Key.remindersEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.remindersEnabled) }
    }

    var notificationHour: Int {
        get { defaults.object(forKey: Key.notifHour) as? Int ?? 9 }
        set { defaults.set(newValue, forKey: Key.notifHour) }
    }
    var notificationMinute: Int {
        get { defaults.object(forKey: Key.notifMinute) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Key.notifMinute) }
    }
    func setNotificationTime(hour: Int, minute: Int) {
        notificationHour = hour
        notificationMinute = minute
    }

    // MARK: New-day offset (drives HabitStats.dayStartHour)
    /// 0 = midnight; +1…+6 = early-morning rollover (a 1 AM check-in still counts
    /// for "yesterday"); −1…−3 = late-evening rollover for extreme night owls.
    var dayStartHour: Int {
        get { defaults.integer(forKey: Key.dayStartHour) } // default 0
        set {
            defaults.set(newValue, forKey: Key.dayStartHour)
            HabitStats.dayStartHour = newValue
        }
    }

    // MARK: Start-of-week (ISO 1 = Mon … 7 = Sun; drives HabitStats.weekStartDay)
    var weekStartDay: Int {
        get { defaults.object(forKey: Key.weekStart) as? Int ?? 1 }
        set {
            defaults.set(newValue, forKey: Key.weekStart)
            HabitStats.weekStartDay = newValue
        }
    }

    // MARK: Day-rollover review gate
    var lastActiveDay: String? {
        get { defaults.string(forKey: Key.lastActiveDay) }
        set { defaults.set(newValue, forKey: Key.lastActiveDay) }
    }

    // MARK: Appearance
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }
    var appearance: Appearance {
        get { Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "system") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    // MARK: Notification permission gating
    var notificationPermissionRequested: Bool {
        get { defaults.bool(forKey: Key.onboardedNotifications) }
        set { defaults.set(newValue, forKey: Key.onboardedNotifications) }
    }
}
