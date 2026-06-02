import Foundation

/// Static catalogue mirrored from Android's `Constants.kt`. The habit icon set
/// keeps the **same stable keys** (stored on `Habit.emoji`) so a habit created
/// on Android shows a sensible icon on iOS and vice-versa — only the rendering
/// differs (Android ships vector drawables; iOS maps each key to an SF Symbol).
enum AppConstants {

    /// (stable key, SF Symbol name, short label). The key is what's persisted;
    /// many later entries double as "quit"/avoid glyphs.
    static let habitIcons: [(key: String, symbol: String, label: String)] = [
        ("target", "target", "Goal"),
        ("water", "drop.fill", "Water"),
        ("sprout", "leaf.fill", "Grow"),
        ("dumbbell", "dumbbell.fill", "Gym"),
        ("book", "book.fill", "Read"),
        ("meditation", "figure.mind.and.body", "Calm"),
        ("sun", "sun.max.fill", "Morning"),
        ("moon", "moon.fill", "Night"),
        ("heart", "heart.fill", "Health"),
        ("flame", "flame.fill", "Streak"),
        ("cup", "cup.and.saucer.fill", "Coffee"),
        ("bell", "bell.fill", "Alarm"),
        ("pencil", "pencil", "Write"),
        ("walk", "figure.walk", "Walk"),
        ("bike", "bicycle", "Cycle"),
        ("timer", "timer", "Focus"),
        ("bed", "bed.double.fill", "Sleep"),
        ("apple", "fork.knife", "Eat"),
        ("pill", "pills.fill", "Meds"),
        ("money", "indianrupeesign.circle.fill", "Money"),
        ("code", "chevron.left.forwardslash.chevron.right", "Code"),
        ("music", "music.note", "Music"),
        ("star", "star.fill", "Reward"),
        ("globe", "globe", "Learn"),
        ("phone_off", "iphone.slash", "Screen"),
        ("no_smoking", "nosign", "Smoke"),
        ("glass", "wineglass.fill", "Alcohol")
    ]

    private static let symbolByKey: [String: String] =
        Dictionary(uniqueKeysWithValues: habitIcons.map { ($0.key, $0.symbol) })

    /// SF Symbol for a habit icon key, falling back to the default when unknown.
    static func symbol(for key: String?) -> String {
        guard let key else { return "target" }
        return symbolByKey[key] ?? "target"
    }

    /// ISO weekday short labels, index 0 = Mon … 6 = Sun.
    static let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    static let dayLabelsFull = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}
