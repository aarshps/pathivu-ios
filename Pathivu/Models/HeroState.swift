import Foundation

/// Aggregate state driving the hero "today" card. Mirrors Android's
/// `MainViewModel.HeroState`.
struct HeroState: Equatable {
    var totalActive: Int = 0
    var dueToday: Int = 0
    var doneToday: Int = 0
    var slipsToday: Int = 0
    var bestStreak: Int = 0
    var dayStreak: Int = 0

    var allDone: Bool { dueToday > 0 && doneToday >= dueToday }
    var progress: Double { dueToday == 0 ? 0 : Double(doneToday) / Double(dueToday) }
    /// Net daily score: positive completions minus negative slips.
    var score: Int { doneToday - slipsToday }
}
