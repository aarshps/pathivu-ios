import Foundation
import FirebaseFirestore

/// Owns reads/writes against Firestore. Layout mirrors the Android app exactly
/// so both clients hit the same documents:
///
///   - users/{uid}/habits/{habitId}
///
/// Completion history is a `completedDates: [String]` array on each habit doc,
/// toggled with atomic `arrayUnion` / `arrayRemove` so check-offs are race-free
/// across devices. This is identical to `pathivu-android`.
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore

    init() {
        self.db = Firestore.firestore()
    }

    private func habitsCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("habits")
    }

    // MARK: Live habit list
    /// Streams every change to the user's habit collection (active *and*
    /// archived — callers filter). Closes when the returned registration is
    /// removed.
    func observeHabits(
        uid: String,
        onChange: @escaping ([Habit]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        habitsCollection(uid: uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onError(error)
                    return
                }
                let docs = snapshot?.documents ?? []
                let habits: [Habit] = docs.compactMap { try? $0.data(as: Habit.self) }
                onChange(habits)
            }
    }

    /// One-shot fetch (used by the notification scheduler).
    func fetchHabits(uid: String) async throws -> [Habit] {
        let snapshot = try await habitsCollection(uid: uid).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Habit.self) }
    }

    // MARK: Completion toggle
    /// Atomically toggle `habit`'s completion on `date` (any day — drives the
    /// home check-off and the Day-editor back-fill).
    func toggle(_ habit: Habit, on date: Date, uid: String) async throws {
        guard let id = habit.id else { return }
        let dayKey = HabitStats.key(date)
        let op = habit.completedDates.contains(dayKey)
            ? FieldValue.arrayRemove([dayKey])
            : FieldValue.arrayUnion([dayKey])
        try await habitsCollection(uid: uid).document(id).updateData(["completedDates": op])
    }

    // MARK: Create / edit
    /// Upsert a habit. On create, seeds `createdAt`, empty `completedDates`, and
    /// a bottom-of-list `sortOrder`. On edit, merges so completion history and
    /// creation time are preserved (mirrors Android's `SetOptions.merge()`).
    func saveHabit(
        existingId: String?,
        name: String,
        emoji: String,
        scheduleType: String,
        daysOfWeek: [Int],
        weeklyTarget: Int,
        monthlyTarget: Int,
        negative: Bool,
        uid: String
    ) async throws {
        var data: [String: Any] = [
            "name": name,
            "emoji": emoji,
            "colorIndex": 0,
            "scheduleType": scheduleType,
            "daysOfWeek": daysOfWeek,
            "weeklyTarget": weeklyTarget,
            "monthlyTarget": monthlyTarget,
            "negative": negative,
            "archived": false
        ]
        let collection = habitsCollection(uid: uid)
        if let existingId {
            try await collection.document(existingId).setData(data, merge: true)
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            data["completedDates"] = [String]()
            data["sortOrder"] = Int(Date().timeIntervalSince1970 * 1000)
            _ = try await collection.addDocument(data: data)
        }
    }

    // MARK: Reorder
    /// Persist a drag-arranged order: writes each habit's list index to `sortOrder`.
    func persistOrder(_ ordered: [Habit], uid: String) async throws {
        let batch = db.batch()
        for (index, habit) in ordered.enumerated() {
            guard let id = habit.id else { continue }
            batch.updateData(["sortOrder": index], forDocument: habitsCollection(uid: uid).document(id))
        }
        try await batch.commit()
    }

    // MARK: Archive / restore / delete
    /// Soft-delete: drops a habit out of active tracking but keeps its history.
    func archive(_ habit: Habit, uid: String) async throws {
        guard let id = habit.id else { return }
        try await habitsCollection(uid: uid).document(id).updateData(["archived": true])
    }

    func restore(_ habit: Habit, uid: String) async throws {
        guard let id = habit.id else { return }
        try await habitsCollection(uid: uid).document(id).updateData([
            "archived": false,
            "sortOrder": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    /// Permanent delete (used from Settings → Archived habits).
    func delete(_ habit: Habit, uid: String) async throws {
        guard let id = habit.id else { return }
        try await habitsCollection(uid: uid).document(id).delete()
    }

    /// Wipes every habit the user owns. Called from the Settings → Delete Account
    /// flow before `Auth.user.delete()`. Best-effort.
    func deleteAllUserData(uid: String) async throws {
        let snap = try await habitsCollection(uid: uid).getDocuments()
        for doc in snap.documents {
            try? await doc.reference.delete()
        }
        try? await db.collection("users").document(uid).delete()
    }
}
