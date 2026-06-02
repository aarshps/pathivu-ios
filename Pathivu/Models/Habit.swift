import Foundation
import FirebaseFirestore

/// A habit the user is building (or a "quit" habit they're avoiding). Stored at
/// `users/{uid}/habits/{habitId}` in Firestore.
///
/// Completion history lives directly on the document as a list of ISO
/// `yyyy-MM-dd` date strings (`completedDates`). For a personal habit tracker
/// this comfortably fits inside Firestore's 1 MB document ceiling and lets the
/// home screen render streaks, week-dots and the heatmap from a single read.
/// Toggling a day is an atomic `arrayUnion` / `arrayRemove`, so it is race-free
/// across devices — and the document shape is **identical to the Android app**
/// (`pathivu-android`), so a user can sign in on either platform and see the
/// same habits.
///
/// `Sendable` is intentionally NOT declared: Firebase's `@DocumentID` /
/// `@ServerTimestamp` wrappers aren't `Sendable` in SDK 11.x, and the project
/// runs `SWIFT_STRICT_CONCURRENCY: minimal`.
struct Habit: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String = ""

    /// Key of the habit's line-icon (see `Constants.habitIcons`), e.g. `"water"`.
    /// Field name kept as `emoji` for backwards-compatibility with existing
    /// Firestore documents written by Android; unknown/legacy values fall back
    /// to the default icon.
    var emoji: String = "target"

    /// Legacy accent index — no longer used (habits use the app accent).
    var colorIndex: Int = 0

    var category: String = "Health"

    /// One of the `schedule*` constants below.
    var scheduleType: String = Habit.scheduleDaily

    /// For `scheduleWeekly`: ISO weekday numbers (1 = Mon … 7 = Sun).
    var daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7]

    /// For `scheduleWeeklyCount`: target completions per week.
    var weeklyTarget: Int = 5

    /// For `scheduleMonthlyCount`: target completions per calendar month.
    var monthlyTarget: Int = 10

    /// A "bad" habit to quit. Marking it done logs a *slip*, which penalises the
    /// day's score and resets the clean-day streak. See `HabitStats`.
    var negative: Bool = false

    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0

    /// ISO `yyyy-MM-dd` strings for every completed day.
    var completedDates: [String] = []

    @ServerTimestamp var createdAt: Timestamp?

    var sortOrder: Int = 0

    var archived: Bool = false

    // MARK: Schedule constants (string-encoded, shared with Android)
    static let scheduleDaily = "daily"
    static let scheduleWeekly = "weekly"
    static let scheduleWeeklyCount = "weekly_count"
    static let scheduleMonthlyCount = "monthly_count"
}

extension Habit {
    var createdAtDate: Date? { createdAt?.dateValue() }

    static let preview = Habit(
        id: "preview-1",
        name: "Drink water",
        emoji: "water",
        scheduleType: Habit.scheduleDaily,
        completedDates: [HabitStats.todayStr()],
        createdAt: Timestamp(date: Date().addingTimeInterval(-86_400 * 30)),
        sortOrder: 0
    )
}
