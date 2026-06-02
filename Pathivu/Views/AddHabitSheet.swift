import SwiftUI
import FirebaseAuth

/// Create / edit a habit. Mirrors Android's `AddHabitBottomSheet`: name, a
/// Build/Quit type toggle, the line-icon picker, and the schedule selector
/// (Daily / specific days / X-per-week / X-per-month). "Quit" habits are daily
/// abstinence, so the schedule island is hidden for them.
struct AddHabitSheet: View {
    let habit: Habit?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedIcon: String
    @State private var scheduleType: String
    @State private var selectedDays: Set<Int>
    @State private var weeklyTarget: Int
    @State private var monthlyTarget: Int
    @State private var negative: Bool

    @State private var nameError = false
    @State private var showDeleteConfirm = false
    @State private var isSaving = false

    init(habit: Habit?) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _selectedIcon = State(initialValue: habit?.emoji ?? AppConstants.habitIcons[0].key)
        _scheduleType = State(initialValue: habit?.scheduleType ?? Habit.scheduleDaily)
        _selectedDays = State(initialValue: Set(habit?.daysOfWeek.isEmpty == false ? habit!.daysOfWeek : [1, 2, 3, 4, 5, 6, 7]))
        _weeklyTarget = State(initialValue: min(max(habit?.weeklyTarget ?? 5, 1), 7))
        _monthlyTarget = State(initialValue: min(max(habit?.monthlyTarget ?? 10, 1), 28))
        _negative = State(initialValue: habit?.negative ?? false)
    }

    private var isEditing: Bool { habit?.id != nil }
    private var accent: Color { negative ? .red : .accentColor }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    nameField
                    typeIsland
                    iconIsland
                    if !negative { scheduleIsland }
                    if isEditing { deleteButton }
                }
                .padding(18)
            }
            .background(backdrop)
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(isSaving)
                }
            }
            .confirmationDialog("Delete habit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { archive() }
            } message: {
                Text("\"\(habit?.name ?? "")\" leaves your list, but its history stays in the calendar. Permanently remove it later from Settings → Archived habits.")
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var backdrop: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }

    // MARK: Name + avatar
    private var nameField: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Image(systemName: AppConstants.symbol(for: selectedIcon))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Habit name", text: $name)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .onChange(of: name) { _, _ in nameError = false }
                if nameError {
                    Text("Give your habit a name")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    // MARK: Build / Quit
    private var typeIsland: some View {
        VStack(alignment: .leading, spacing: 12) {
            segmented(
                options: [(false, "Build"), (true, "Quit")],
                selection: negative,
                tint: negative ? .red : .accentColor
            ) { value in
                Haptics.tick()
                negative = value
            }
            Text(negative
                 ? "A bad habit to quit. Marking it means you slipped today — it lowers today's score and resets your clean-day streak."
                 : "A good habit to build and repeat.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    // MARK: Icon picker
    private var iconIsland: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ICON")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppConstants.habitIcons, id: \.key) { icon in
                        VStack(spacing: 5) {
                            ZStack {
                                Circle().fill(selectedIcon == icon.key ? accent : Color.secondary.opacity(0.14))
                                Image(systemName: icon.symbol)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(selectedIcon == icon.key ? Color.white : .secondary)
                            }
                            .frame(width: 48, height: 48)
                            Text(icon.label)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 52)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            Haptics.tick()
                            selectedIcon = icon.key
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    // MARK: Schedule
    private var scheduleIsland: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SCHEDULE")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)

            segmented(
                options: [
                    (Habit.scheduleDaily, "Daily"),
                    (Habit.scheduleWeekly, "Days"),
                    (Habit.scheduleWeeklyCount, "×/wk"),
                    (Habit.scheduleMonthlyCount, "×/mo")
                ],
                selection: scheduleType,
                tint: .accentColor
            ) { value in
                Haptics.tick()
                scheduleType = value
            }

            if scheduleType == Habit.scheduleWeekly {
                dayChips
            } else if scheduleType == Habit.scheduleWeeklyCount {
                counter(value: $weeklyTarget, range: 1...7, suffix: "× per week")
            } else if scheduleType == Habit.scheduleMonthlyCount {
                counter(value: $monthlyTarget, range: 1...28, suffix: "× per month")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var dayChips: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { iso in
                let on = selectedDays.contains(iso)
                Text(AppConstants.dayLabels[iso - 1])
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(on ? Color.accentColor : Color.secondary.opacity(0.14), in: .circle)
                    .foregroundStyle(on ? Color.white : .primary)
                    .onTapGesture {
                        Haptics.tick()
                        if on { selectedDays.remove(iso) } else { selectedDays.insert(iso) }
                    }
            }
        }
    }

    private func counter(value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        VStack(spacing: 8) {
            Text("\(value.wrappedValue) \(suffix)")
                .font(.system(.body, design: .rounded, weight: .medium))
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(.accentColor)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            Haptics.warning()
            showDeleteConfirm = true
        } label: {
            Label("Delete habit", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(.red)
    }

    // MARK: Generic segmented control
    private func segmented<T: Equatable>(
        options: [(T, String)],
        selection: T,
        tint: Color,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                let (value, label) = options[i]
                let isOn = value == selection
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isOn ? tint.opacity(0.9) : Color.clear, in: .rect(cornerRadius: 12))
                    .foregroundStyle(isOn ? Color.white : .secondary)
                    .contentShape(.rect)
                    .onTapGesture { onSelect(value) }
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
    }

    // MARK: Actions
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameError = true
            Haptics.error()
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Haptics.success()
        isSaving = true

        let finalSchedule = negative ? Habit.scheduleDaily : scheduleType
        let days: [Int]
        if finalSchedule == Habit.scheduleWeekly {
            days = selectedDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : selectedDays.sorted()
        } else {
            days = [1, 2, 3, 4, 5, 6, 7]
        }

        Task {
            do {
                try await FirestoreService.shared.saveHabit(
                    existingId: habit?.id,
                    name: trimmed,
                    emoji: selectedIcon,
                    scheduleType: finalSchedule,
                    daysOfWeek: days,
                    weeklyTarget: weeklyTarget,
                    monthlyTarget: monthlyTarget,
                    negative: negative,
                    uid: uid
                )
                AppAnalytics.habitSave(isNew: !isEditing, schedule: negative ? "negative" : finalSchedule)
                dismiss()
            } catch {
                isSaving = false
                Haptics.error()
            }
        }
    }

    private func archive() {
        guard let uid = Auth.auth().currentUser?.uid, let habit else { return }
        Task {
            try? await FirestoreService.shared.archive(habit, uid: uid)
            AppAnalytics.habitArchive()
            dismiss()
        }
    }
}

#Preview {
    AddHabitSheet(habit: nil)
}
