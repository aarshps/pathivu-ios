import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Back-fill editor: pick any past day and toggle each habit's completion for
/// that date. Self-contained — holds its own Firestore listener and writes the
/// same atomic `arrayUnion`/`arrayRemove` the home list uses, so changes flow
/// back to every other screen live. Future days are not reachable. Mirrors
/// Android's `DayEditorBottomSheet`.
struct DayEditorSheet: View {
    let initialDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var habits: [Habit] = []
    @State private var listener: ListenerRegistration?
    @State private var showPicker = false

    init(initialDate: Date = HabitStats.today()) {
        self.initialDate = initialDate
        _selectedDate = State(initialValue: initialDate)
    }

    private var atToday: Bool { selectedDate >= HabitStats.today() }

    private var title: String {
        let today = HabitStats.today()
        if selectedDate == today { return "Today" }
        if selectedDate == HabitStats.addDays(today, -1) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var subtitle: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if habits.isEmpty {
                        Text("No habits to log yet.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(habits) { habit in
                            row(habit)
                        }
                    }
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Day editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: startListener)
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .sheet(isPresented: $showPicker) {
            datePickerSheet
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.click()
                selectedDate = HabitStats.addDays(selectedDate, -1)
            } label: {
                Image(systemName: "chevron.left").font(.title3)
            }

            Spacer()

            Button {
                Haptics.click()
                showPicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                guard !atToday else { return }
                Haptics.click()
                selectedDate = HabitStats.addDays(selectedDate, 1)
            } label: {
                Image(systemName: "chevron.right").font(.title3)
            }
            .disabled(atToday)
            .opacity(atToday ? 0.3 : 1)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }

    private func row(_ habit: Habit) -> some View {
        let done = habit.completedDates.contains(HabitStats.key(selectedDate))
        let accent: Color = habit.negative ? .red : .accentColor
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Image(systemName: AppConstants.symbol(for: habit.emoji))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text(habit.archived ? "Archived · \(HabitStats.scheduleLabel(habit))" : HabitStats.scheduleLabel(habit))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                toggle(habit)
            } label: {
                ZStack {
                    Circle().fill(done ? accent : Color.secondary.opacity(0.14))
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(done ? Color.white : accent.opacity(0.5))
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.background, in: .rect(cornerRadius: 20))
        .opacity(habit.archived ? 0.6 : 1)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Pick a day",
                selection: $selectedDate,
                in: ...HabitStats.today(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Pick a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if selectedDate > HabitStats.today() { selectedDate = HabitStats.today() }
                        showPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func startListener() {
        AppAnalytics.screenDayEditorOpen()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = FirestoreService.shared.observeHabits(
            uid: uid,
            onChange: { all in
                // Active habits + archived ones that still carry history, so the
                // calendar keeps showing a deleted habit's past completions.
                habits = all
                    .filter { !$0.archived || !$0.completedDates.isEmpty }
                    .sorted { lhs, rhs in
                        if lhs.archived != rhs.archived { return !lhs.archived && rhs.archived }
                        return lhs.sortOrder < rhs.sortOrder
                    }
            },
            onError: { _ in }
        )
    }

    private func toggle(_ habit: Habit) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Haptics.success()
        AppAnalytics.habitToggleBackfill()
        Task { try? await FirestoreService.shared.toggle(habit, on: selectedDate, uid: uid) }
    }
}

#Preview {
    DayEditorSheet()
}
