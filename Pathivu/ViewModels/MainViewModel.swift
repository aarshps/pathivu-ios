import Foundation
import FirebaseAuth
import FirebaseFirestore
import Observation

/// Drives the home screen: observes the user's habits, derives the hero "today"
/// state, and exposes the toggle / reorder / archive mutations. Mirrors Android's
/// `MainViewModel`, but built on the Observation framework (`@Observable`) and
/// injected via `@Environment`.
@Observable
@MainActor
final class MainViewModel {

    /// All active habits, sorted by the user's drag order (then creation time).
    private(set) var habits: [Habit] = []
    private(set) var isLoading = true
    private(set) var hero = HeroState()
    var errorMessage: String?

    private var listener: ListenerRegistration?

    var isSignedIn: Bool { Auth.auth().currentUser != nil }

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        listener?.remove()
        isLoading = true
        listener = FirestoreService.shared.observeHabits(
            uid: uid,
            onChange: { [weak self] all in
                Task { @MainActor in self?.apply(all) }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        )
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    private func apply(_ all: [Habit]) {
        let active = all.filter { !$0.archived }

        // Honour the user's drag-arranged sortOrder; newly-added habits
        // (sortOrder = creation millis) fall to the bottom until reordered.
        let sorted = active.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.createdAtDate ?? .distantFuture) < (rhs.createdAtDate ?? .distantFuture)
        }

        let positives = active.filter { !$0.negative }
        let negatives = active.filter { $0.negative }
        let due = positives.filter { HabitStats.isDueToday($0) }

        habits = sorted
        hero = HeroState(
            totalActive: active.count,
            dueToday: due.count,
            doneToday: due.filter { HabitStats.isDoneToday($0) }.count,
            slipsToday: negatives.filter { HabitStats.isDoneToday($0) }.count,
            bestStreak: positives.map { HabitStats.currentStreak($0) }.max() ?? 0,
            dayStreak: HabitStats.dayStreak(active)
        )
        isLoading = false

        // Keep the local reminder summary in step with the latest data.
        Task { await NotificationScheduler.reschedule(for: active) }
    }

    // MARK: Mutations

    func toggleToday(_ habit: Habit) {
        toggle(habit, on: HabitStats.today())
    }

    func toggle(_ habit: Habit, on date: Date) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        AppAnalytics.habitToggle(done: !HabitStats.isDone(habit, date))
        Haptics.success()
        Task {
            do { try await FirestoreService.shared.toggle(habit, on: date, uid: uid) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    /// Persist a new order after a drag. Optimistically updates `habits` so the
    /// list doesn't flicker before the Firestore round-trip lands.
    func persistOrder(_ ordered: [Habit]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        habits = ordered
        AppAnalytics.habitReorder()
        Task {
            do { try await FirestoreService.shared.persistOrder(ordered, uid: uid) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func archive(_ habit: Habit) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        AppAnalytics.habitArchive()
        Task {
            do { try await FirestoreService.shared.archive(habit, uid: uid) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
