import SwiftUI

/// The "today" hero: a circular progress ring with the done/due count, plus a
/// motivational title and a streak / slip subtitle. Mirrors Android's
/// `updateHeroSection`.
struct HeroSection: View {
    let hero: HeroState

    private var label: String { hero.totalActive == 0 ? "LET'S GO" : "TODAY" }

    private var title: String {
        if hero.totalActive == 0 { return "Start your first habit" }
        if hero.dueToday == 0 { return "No habits today" }
        if hero.allDone { return "All done" }
        let left = hero.dueToday - hero.doneToday
        return "\(left) \(left == 1 ? "habit" : "habits") to go"
    }

    private var centerText: String {
        if hero.totalActive == 0 { return "0" }
        return hero.dueToday == 0 ? "—" : "\(hero.doneToday)/\(hero.dueToday)"
    }

    private var subtitle: (text: String, isSlip: Bool) {
        if hero.totalActive == 0 { return ("Tap + to begin", false) }
        if hero.slipsToday > 0 {
            let s = hero.slipsToday == 1 ? "slip" : "slips"
            return ("−\(hero.slipsToday) \(s) today", true)
        }
        if hero.dayStreak > 0 { return ("\(hero.dayStreak)-day streak", false) }
        if hero.dueToday == 0 { return ("Enjoy your rest day", false) }
        if hero.allDone { return ("Great work today", false) }
        return ("Keep it going", false)
    }

    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.001, hero.progress))
                    .stroke(
                        AngularGradient(
                            colors: [Color.accentColor.opacity(0.7), Color.accentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: hero.progress)
                Text(centerText)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.tint)
                    .tracking(1.5)
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(subtitle.isSlip ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 32))
    }
}

#Preview {
    HeroSection(hero: HeroState(totalActive: 4, dueToday: 4, doneToday: 2, slipsToday: 0, bestStreak: 6, dayStreak: 3))
        .padding()
}
