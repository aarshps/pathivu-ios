import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Stats screen: four summary tiles, a 16-week contribution heatmap, and a
/// per-habit breakdown sorted by current streak. Mirrors Android's
/// `StatsActivity`. Holds its own Firestore listener over active habits.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var habits: [Habit] = []
    @State private var listener: ListenerRegistration?

    private var positives: [Habit] { habits.filter { !$0.negative } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    tiles
                    heatmapCard
                    breakdown
                }
                .padding(18)
            }
            .background(backdrop)
            .navigationTitle("Stats")
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
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.14), Color(.systemGroupedBackground)],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }

    // MARK: Tiles
    private var tiles: some View {
        let due = positives.filter { HabitStats.isDueToday($0) }
        let doneToday = due.filter { HabitStats.isDoneToday($0) }.count
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile(value: due.isEmpty ? "—" : "\(doneToday)/\(due.count)", label: "Done today", systemImage: "checkmark.circle.fill")
            tile(value: "\(HabitStats.dayStreak(habits))", label: "Day streak", systemImage: "flame.fill")
            tile(value: "\(overallRate())%", label: "30-day rate", systemImage: "chart.line.uptrend.xyaxis")
            tile(value: "\(habits.count)", label: "Active habits", systemImage: "square.stack.3d.up.fill")
        }
    }

    private func tile(value: String, label: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(.tint)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    // MARK: Heatmap
    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAST 16 WEEKS")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            ScrollView(.horizontal, showsIndicators: false) {
                HeatmapGrid(data: HabitStats.heatmapAll(positives, weeks: 16))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    // MARK: Per-habit breakdown
    private var breakdown: some View {
        VStack(spacing: 8) {
            if habits.isEmpty {
                Text("No habits yet.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 30)
            } else {
                ForEach(habits.sorted { HabitStats.currentStreak($0) > HabitStats.currentStreak($1) }) { habit in
                    habitRow(habit)
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let accent: Color = habit.negative ? .red : .accentColor
        let cur = HabitStats.currentStreak(habit)
        let unit: String
        switch true {
        case habit.negative: unit = "days clean"
        case habit.scheduleType == Habit.scheduleWeeklyCount: unit = "wk streak"
        case habit.scheduleType == Habit.scheduleMonthlyCount: unit = "mo streak"
        default: unit = "day streak"
        }
        let rate = HabitStats.completionRate(habit, days: 30)
        let shownRate = habit.negative ? 100 - rate : rate
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Image(systemName: AppConstants.symbol(for: habit.emoji))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text("\(cur) \(unit)  ·  \(HabitStats.totalCompletions(habit)) done")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(shownRate)%")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.background, in: .rect(cornerRadius: 20))
    }

    // MARK: Data
    private func overallRate() -> Int {
        let habits = positives
        if habits.isEmpty { return 0 }
        var scheduled = 0
        var done = 0
        var cursor = HabitStats.today()
        for _ in 0..<30 {
            let key = HabitStats.key(cursor)
            for h in habits where HabitStats.isScheduledOn(h, cursor) {
                scheduled += 1
                if h.completedDates.contains(key) { done += 1 }
            }
            cursor = HabitStats.addDays(cursor, -1)
        }
        return scheduled == 0 ? 0 : Int((Double(done) * 100 / Double(scheduled)).rounded())
    }

    private func startListener() {
        AppAnalytics.screenStatsOpen()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = FirestoreService.shared.observeHabits(
            uid: uid,
            onChange: { all in habits = all.filter { !$0.archived } },
            onError: { _ in }
        )
    }
}

/// GitHub-style contribution grid. `data` is weeks × 7 day-cells; `-1` = future.
struct HeatmapGrid: View {
    let data: [[Float]]
    private let cell: CGFloat = 15
    private let gap: CGFloat = 4

    var body: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(data.indices, id: \.self) { w in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { d in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color(for: data[w][d]))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func color(for intensity: Float) -> Color {
        if intensity < 0 { return .clear }            // future
        if intensity == 0 { return Color.secondary.opacity(0.14) }
        return Color.accentColor.opacity(0.25 + Double(intensity) * 0.75)
    }
}

#Preview {
    StatsView()
}
