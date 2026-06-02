import SwiftUI

/// One habit card on the home list: avatar, name, schedule line, streak, the
/// week-dot strip, and the spring-animated check button. Mirrors Android's
/// `HabitAdapter` item.
struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void
    let onTap: () -> Void

    @State private var checkScale: CGFloat = 1

    private var accent: Color { habit.negative ? .red : .accentColor }
    private var dueToday: Bool { HabitStats.isDueToday(habit) }
    private var doneToday: Bool { HabitStats.isDoneToday(habit) }
    private var streak: Int { HabitStats.currentStreak(habit) }

    private var scheduleText: String {
        if habit.negative { return "Avoid daily" }
        switch habit.scheduleType {
        case Habit.scheduleMonthlyCount:
            let p = HabitStats.monthProgress(habit); return "\(p.done)/\(p.target) this month"
        case Habit.scheduleWeeklyCount:
            let p = HabitStats.weekProgress(habit); return "\(p.done)/\(p.target) this week"
        default:
            return dueToday ? HabitStats.scheduleLabel(habit) : "Rest day"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(habit.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").font(.caption2)
                            Text(habit.negative ? "\(streak) clean" : "\(streak)")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(accent)
                    }
                }
                Text(scheduleText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                weekDots
            }

            Spacer(minLength: 4)

            checkButton
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 26))
        .opacity(dueToday ? 1 : 0.65)
        .contentShape(.rect)
        .onTapGesture {
            Haptics.tick()
            onTap()
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(accent.opacity(habit.negative ? 0.18 : 0.16))
            Image(systemName: AppConstants.symbol(for: habit.emoji))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(width: 46, height: 46)
    }

    private var weekDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(HabitStats.weekRow(habit).enumerated()), id: \.offset) { _, cell in
                dot(for: cell.status)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func dot(for status: HabitStats.DayStatus) -> some View {
        switch status {
        case .done:
            Circle().fill(accent).frame(width: 9, height: 9)
        case .todayPending:
            Circle().stroke(accent, lineWidth: 2).frame(width: 9, height: 9)
        case .missed:
            Circle().fill(Color.secondary.opacity(0.35)).frame(width: 9, height: 9)
        case .notScheduled:
            Circle().fill(Color.secondary.opacity(0.15)).frame(width: 9, height: 9)
        case .future:
            Circle().fill(Color.secondary.opacity(0.12)).frame(width: 9, height: 9)
        }
    }

    private var checkButton: some View {
        Button {
            Haptics.success()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { checkScale = 0.8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { checkScale = 1 }
            }
            onToggle()
        } label: {
            ZStack {
                Circle()
                    .fill(doneToday ? accent : Color.secondary.opacity(0.14))
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(doneToday ? Color.white : accent.opacity(dueToday ? 0.55 : 0.3))
            }
            .frame(width: 46, height: 46)
            .scaleEffect(checkScale)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HabitRow(habit: .preview, onToggle: {}, onTap: {})
        .padding()
}
