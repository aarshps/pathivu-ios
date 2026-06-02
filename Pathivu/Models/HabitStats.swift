import Foundation

/// Pure, side-effect-free habit analytics derived from `Habit.completedDates`
/// plus the habit's schedule. Everything the UI shows about progress — streaks,
/// week-dots, completion rate, the heatmap — is computed here so there is a
/// single source of truth and the Firestore document stays a plain data bag.
///
/// This is a 1:1 port of Android's `util/HabitStats.kt`. Dates are ISO
/// `yyyy-MM-dd`; weekday numbers follow ISO-8601 (1 = Mon … 7 = Sun).
enum HabitStats {

    enum DayStatus { case done, missed, todayPending, notScheduled, future }

    /// Hour at which a new day begins (0 = midnight, 3 = 3 AM …). Lets a night-owl
    /// log a habit after midnight and still have it count for the previous day.
    /// Set from prefs at app startup and whenever changed in Settings.
    static var dayStartHour: Int = 0

    /// First day of the week (ISO: 1 = Mon … 7 = Sun). Drives week dots, week
    /// streaks, heatmap.
    static var weekStartDay: Int = 1

    // MARK: - Calendar plumbing

    /// Gregorian calendar in the device's current timezone. All day math goes
    /// through `Calendar.date(byAdding:)` so it stays DST-safe.
    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// ISO `yyyy-MM-dd` key for a date.
    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    private static func parse(_ key: String) -> Date? { keyFormatter.date(from: key) }

    private static func startOfDay(_ date: Date) -> Date { cal.startOfDay(for: date) }

    static func addDays(_ date: Date, _ days: Int) -> Date {
        cal.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func addWeeks(_ date: Date, _ weeks: Int) -> Date {
        cal.date(byAdding: .day, value: weeks * 7, to: date) ?? date
    }

    private static func addMonths(_ date: Date, _ months: Int) -> Date {
        cal.date(byAdding: .month, value: months, to: date) ?? date
    }

    /// ISO weekday for a date: 1 = Mon … 7 = Sun.
    static func isoWeekday(_ date: Date) -> Int {
        let wd = cal.component(.weekday, from: date) // 1 = Sun … 7 = Sat
        return ((wd + 5) % 7) + 1
    }

    /// First day of `date`'s week, honouring the configurable `weekStartDay`.
    private static func weekStart(_ date: Date) -> Date {
        let wd = isoWeekday(date)
        let ws = min(max(weekStartDay, 1), 7)
        let back = ((wd - ws) + 7) % 7
        return startOfDay(addDays(date, -back))
    }

    // MARK: - Today

    /// "Today", honouring `dayStartHour` — before that hour it's still yesterday.
    static func today() -> Date {
        let shifted = cal.date(byAdding: .hour, value: -dayStartHour, to: Date()) ?? Date()
        return startOfDay(shifted)
    }

    static func todayStr() -> String { key(today()) }

    static func isDone(_ habit: Habit, _ date: Date) -> Bool {
        habit.completedDates.contains(key(date))
    }

    static func isDoneToday(_ habit: Habit) -> Bool { isDone(habit, today()) }

    /// Whether the habit is meant to be performed on `date`.
    static func isScheduledOn(_ habit: Habit, _ date: Date) -> Bool {
        switch habit.scheduleType {
        case Habit.scheduleWeekly:
            return habit.daysOfWeek.contains(isoWeekday(date))
        default:
            // Daily and "x per week/month" habits are eligible any day.
            return true
        }
    }

    static func isDueToday(_ habit: Habit) -> Bool { isScheduledOn(habit, today()) }

    // MARK: - Streaks

    /// Current streak, **interpreted per schedule** so the flame always means the
    /// right thing.
    static func currentStreak(_ habit: Habit) -> Int {
        if habit.negative { return cleanStreak(habit) }
        switch habit.scheduleType {
        case Habit.scheduleWeeklyCount: return weeklyStreak(habit)
        case Habit.scheduleMonthlyCount: return monthlyStreak(habit)
        default: return dailyStreak(habit)
        }
    }

    /// Consecutive *scheduled* days completed, ending today (or the most recent
    /// scheduled day). If today is scheduled but not yet done, the streak is not
    /// broken — it counts up to yesterday.
    private static func dailyStreak(_ habit: Habit) -> Int {
        if habit.completedDates.isEmpty { return 0 }
        let done = Set(habit.completedDates)
        var cursor = today()
        if isScheduledOn(habit, cursor) && !done.contains(key(cursor)) {
            cursor = addDays(cursor, -1)
        }
        var streak = 0
        var guardCount = 0
        while guardCount < 3660 {
            guardCount += 1
            if isScheduledOn(habit, cursor) {
                if done.contains(key(cursor)) { streak += 1 } else { break }
            }
            cursor = addDays(cursor, -1)
        }
        return streak
    }

    private static func completionsInRange(_ done: Set<String>, _ start: Date, _ endInclusive: Date) -> Int {
        var count = 0
        var d = start
        while d <= endInclusive {
            if done.contains(key(d)) { count += 1 }
            d = addDays(d, 1)
        }
        return count
    }

    private static func monthBounds(_ date: Date) -> (first: Date, last: Date) {
        let comps = cal.dateComponents([.year, .month], from: date)
        let first = cal.date(from: comps) ?? startOfDay(date)
        let range = cal.range(of: .day, in: .month, for: first) ?? 1..<29
        let last = addDays(first, (range.count) - 1)
        return (startOfDay(first), startOfDay(last))
    }

    private static func completionsInMonth(_ done: Set<String>, _ monthAnchor: Date) -> Int {
        let (first, last) = monthBounds(monthAnchor)
        return completionsInRange(done, first, last)
    }

    /// Consecutive ISO weeks (ending this week) that met the weekly target. The
    /// in-progress current week never *breaks* the streak.
    private static func weeklyStreak(_ habit: Habit) -> Int {
        let target = max(habit.weeklyTarget, 1)
        let done = Set(habit.completedDates)
        let thisWeekStart = weekStart(today())
        var streak = 0
        if completionsInRange(done, thisWeekStart, addDays(thisWeekStart, 6)) >= target { streak += 1 }
        var wkStart = addWeeks(thisWeekStart, -1)
        var guardCount = 0
        while guardCount < 520 {
            guardCount += 1
            if completionsInRange(done, wkStart, addDays(wkStart, 6)) >= target { streak += 1 } else { break }
            wkStart = addWeeks(wkStart, -1)
        }
        return streak
    }

    /// Consecutive calendar months (ending this month) that met the monthly target.
    private static func monthlyStreak(_ habit: Habit) -> Int {
        let target = max(habit.monthlyTarget, 1)
        let done = Set(habit.completedDates)
        let thisMonth = today()
        var streak = 0
        if completionsInMonth(done, thisMonth) >= target { streak += 1 }
        var m = addMonths(thisMonth, -1)
        var guardCount = 0
        while guardCount < 1200 {
            guardCount += 1
            if completionsInMonth(done, m) >= target { streak += 1 } else { break }
            m = addMonths(m, -1)
        }
        return streak
    }

    /// Negative habits: consecutive *clean* days (no slip), counting today, since
    /// the later of the last slip or the habit's creation. A slip today → 0.
    private static func cleanStreak(_ habit: Habit) -> Int {
        let todayD = today()
        let lastSlip = habit.completedDates
            .compactMap { parse($0) }
            .map { startOfDay($0) }
            .filter { $0 <= todayD }
            .max()
        if let lastSlip, lastSlip == todayD { return 0 }
        let created = habit.createdAtDate.map { startOfDay($0) }
        let startCounting: Date
        if let lastSlip {
            let dayAfter = addDays(lastSlip, 1)
            startCounting = (created != nil && created! > dayAfter) ? created! : dayAfter
        } else if let created {
            startCounting = created
        } else {
            return 0 // no anchor yet — avoid a bogus huge count
        }
        if startCounting > todayD { return 0 }
        let days = cal.dateComponents([.day], from: startCounting, to: todayD).day ?? 0
        return max(days + 1, 0)
    }

    /// Done / target for the current week (for `weekly_count` cards).
    static func weekProgress(_ habit: Habit) -> (done: Int, target: Int) {
        let start = weekStart(today())
        return (completionsInRange(Set(habit.completedDates), start, addDays(start, 6)), max(habit.weeklyTarget, 1))
    }

    /// Done / target for the current month (for `monthly_count` cards).
    static func monthProgress(_ habit: Habit) -> (done: Int, target: Int) {
        (completionsInMonth(Set(habit.completedDates), today()), max(habit.monthlyTarget, 1))
    }

    /// Global "perfect day" streak: consecutive days where every positively-scheduled
    /// habit due that day was done AND no negative habit was slipped.
    static func dayStreak(_ habits: [Habit]) -> Int {
        let active = habits.filter { !$0.archived }
        if active.isEmpty { return 0 }
        let positives = active.filter { !$0.negative }
        let negatives = active.filter { $0.negative }

        func slippedOn(_ d: Date) -> Bool { negatives.contains { $0.completedDates.contains(key(d)) } }
        func dueOn(_ d: Date) -> [Habit] {
            positives.filter {
                ($0.scheduleType == Habit.scheduleDaily || $0.scheduleType == Habit.scheduleWeekly) &&
                    isScheduledOn($0, d)
            }
        }
        func qualifies(_ d: Date) -> Bool {
            if slippedOn(d) { return false }
            let due = dueOn(d)
            return due.isEmpty || due.allSatisfy { $0.completedDates.contains(key(d)) }
        }

        var cursor = today()
        if !slippedOn(cursor) {
            let due = dueOn(cursor)
            let allDone = !due.isEmpty && due.allSatisfy { $0.completedDates.contains(key(cursor)) }
            if !allDone { cursor = addDays(cursor, -1) }
        }
        let earliest = active.compactMap { $0.createdAtDate.map { startOfDay($0) } }.min()
        var streak = 0
        var guardCount = 0
        while guardCount < 3660 {
            guardCount += 1
            if let earliest, cursor < earliest { break }
            if qualifies(cursor) { streak += 1 } else { break }
            cursor = addDays(cursor, -1)
        }
        return streak
    }

    /// Longest run of consecutive calendar days ever completed.
    static func longestStreak(_ habit: Habit) -> Int {
        if habit.completedDates.isEmpty { return 0 }
        let dates = habit.completedDates.compactMap { parse($0) }.map { startOfDay($0) }.sorted()
        var best = 0
        var run = 0
        var prev: Date?
        for d in dates {
            if let prev, addDays(prev, 1) == d { run += 1 } else { run = 1 }
            if run > best { best = run }
            prev = d
        }
        return best
    }

    static func totalCompletions(_ habit: Habit) -> Int { habit.completedDates.count }

    /// Completion rate (0–100) over the last `days` scheduled days.
    static func completionRate(_ habit: Habit, days: Int = 30) -> Int {
        let done = Set(habit.completedDates)
        var scheduled = 0
        var completed = 0
        var cursor = today()
        for _ in 0..<days {
            if isScheduledOn(habit, cursor) {
                scheduled += 1
                if done.contains(key(cursor)) { completed += 1 }
            }
            cursor = addDays(cursor, -1)
        }
        return scheduled == 0 ? 0 : Int((Double(completed) * 100 / Double(scheduled)).rounded())
    }

    /// Completions in the week containing today.
    static func weekCompletions(_ habit: Habit) -> Int {
        let start = weekStart(today())
        let done = Set(habit.completedDates)
        var count = 0
        for i in 0...6 where done.contains(key(addDays(start, i))) { count += 1 }
        return count
    }

    /// First→last status cells for the current week, for the home row + chips.
    static func weekRow(_ habit: Habit) -> [(date: Date, status: DayStatus)] {
        let today = today()
        let start = weekStart(today)
        let done = Set(habit.completedDates)
        return (0...6).map { i in
            let d = addDays(start, i)
            let status: DayStatus
            if done.contains(key(d)) { status = .done }
            else if d > today { status = .future }
            else if !isScheduledOn(habit, d) { status = .notScheduled }
            else if d == today { status = .todayPending }
            else { status = .missed }
            return (d, status)
        }
    }

    struct HeatCell: Hashable {
        let date: Date
        let isFuture: Bool
        let isDone: Bool
        let isScheduled: Bool
    }

    /// Heatmap data: for the last `weeks` full weeks (oldest → newest), a column
    /// per week of 7 day-cells.
    static func heatmap(_ habit: Habit, weeks: Int = 16) -> [[HeatCell]] {
        let today = today()
        let thisWeekStart = weekStart(today)
        let firstWeekStart = addWeeks(thisWeekStart, -(weeks - 1))
        let done = Set(habit.completedDates)
        return (0..<weeks).map { w in
            let colStart = addWeeks(firstWeekStart, w)
            return (0...6).map { day in
                let d = addDays(colStart, day)
                return HeatCell(
                    date: d,
                    isFuture: d > today,
                    isDone: done.contains(key(d)),
                    isScheduled: isScheduledOn(habit, d)
                )
            }
        }
    }

    /// Heatmap aggregated across multiple habits (intensity = fraction done).
    /// `-1` marks a future day.
    static func heatmapAll(_ habits: [Habit], weeks: Int = 16) -> [[Float]] {
        let today = today()
        let thisWeekStart = weekStart(today)
        let firstWeekStart = addWeeks(thisWeekStart, -(weeks - 1))
        return (0..<weeks).map { w in
            let colStart = addWeeks(firstWeekStart, w)
            return (0...6).map { day -> Float in
                let d = addDays(colStart, day)
                if d > today { return -1 }
                let scheduled = habits.filter { isScheduledOn($0, d) }
                if scheduled.isEmpty { return 0 }
                let doneCount = scheduled.filter { $0.completedDates.contains(key(d)) }.count
                return Float(doneCount) / Float(scheduled.count)
            }
        }
    }

    /// Human-readable schedule summary, e.g. "Daily", "Mon, Wed, Fri",
    /// "5× / week", "10× / month".
    static func scheduleLabel(_ habit: Habit) -> String {
        if habit.negative { return "Avoid daily" }
        switch habit.scheduleType {
        case Habit.scheduleWeekly:
            if habit.daysOfWeek.count == 7 { return "Daily" }
            return habit.daysOfWeek.sorted().map { AppConstants.dayLabelsFull[$0 - 1] }.joined(separator: ", ")
        case Habit.scheduleWeeklyCount:
            return "\(habit.weeklyTarget)× / week"
        case Habit.scheduleMonthlyCount:
            return "\(habit.monthlyTarget)× / month"
        default:
            return "Daily"
        }
    }
}
