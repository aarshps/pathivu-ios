import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Settings → Archived habits. Lists soft-deleted habits (history kept), each
/// with Restore and permanent Delete. Mirrors Android's
/// `ArchivedHabitsBottomSheet`.
struct ArchivedHabitsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var archived: [Habit] = []
    @State private var listener: ListenerRegistration?
    @State private var pendingDelete: Habit?

    var body: some View {
        NavigationStack {
            Group {
                if archived.isEmpty {
                    ContentUnavailableView(
                        "No archived habits",
                        systemImage: "archivebox",
                        description: Text("Habits you delete land here. Their history stays in the calendar.")
                    )
                } else {
                    List {
                        ForEach(archived) { habit in
                            row(habit)
                        }
                    }
                }
            }
            .navigationTitle("Archived habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete permanently?", isPresented: .constant(pendingDelete != nil), titleVisibility: .visible) {
                Button("Delete forever", role: .destructive) {
                    if let h = pendingDelete { hardDelete(h) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("\"\(pendingDelete?.name ?? "")\" and all its history will be erased. This can't be undone.")
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: startListener)
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func row(_ habit: Habit) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.16))
                Image(systemName: AppConstants.symbol(for: habit.emoji))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text("\(HabitStats.totalCompletions(habit)) completions kept")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Haptics.success()
                restore(habit)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .tint(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Haptics.warning()
                pendingDelete = habit
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func startListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = FirestoreService.shared.observeHabits(
            uid: uid,
            onChange: { all in
                archived = all.filter { $0.archived }.sorted { $0.name < $1.name }
            },
            onError: { _ in }
        )
    }

    private func restore(_ habit: Habit) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        AppAnalytics.habitRestore()
        Task { try? await FirestoreService.shared.restore(habit, uid: uid) }
    }

    private func hardDelete(_ habit: Habit) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        AppAnalytics.habitDelete()
        Task { try? await FirestoreService.shared.delete(habit, uid: uid) }
    }
}

#Preview {
    ArchivedHabitsSheet()
}
