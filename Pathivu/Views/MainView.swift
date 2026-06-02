import SwiftUI

/// Home screen: the "today" hero ring above a reorderable list of habit cards,
/// a Liquid-Glass add button, and a toolbar onto the Day editor, Stats, and
/// Settings. Mirrors Android's `MainActivity`.
struct MainView: View {
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var preferences
    @State private var vm = MainViewModel()

    @State private var editingHabit: Habit?
    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var showingStats = false
    @State private var showingDayEditor = false
    @State private var dayEditorStart: Date = HabitStats.today()
    @State private var dayReviewChecked = false

    var body: some View {
        NavigationStack {
            ZStack {
                backdrop
                content
            }
            .navigationTitle("Pathivu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay(alignment: .bottomTrailing) { addButton }
        }
        .task {
            vm.start()
            await NotificationScheduler.requestAuthorization()
        }
        .onChange(of: vm.isLoading) { _, loading in
            if !loading { maybeRunDayReview() }
        }
        .sheet(isPresented: $showingAdd) {
            AddHabitSheet(habit: nil)
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(habit: habit)
        }
        .sheet(isPresented: $showingDayEditor) {
            DayEditorSheet(initialDate: dayEditorStart)
        }
        .sheet(isPresented: $showingStats) {
            StatsView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.16), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView().controlSize(.large)
        } else if vm.habits.isEmpty {
            EmptyState { showingAdd = true }
        } else {
            List {
                Section {
                    HeroSection(hero: vm.hero)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .onTapGesture { showingStats = true }
                }
                Section {
                    ForEach(vm.habits) { habit in
                        HabitRow(
                            habit: habit,
                            onToggle: { vm.toggleToday(habit) },
                            onTap: { editingHabit = habit }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Haptics.warning()
                                vm.archive(habit)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                    .onMove(perform: move)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                AppAnalytics.homeRefreshPull()
                vm.start()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showingSettings = true } label: {
                profileGlyph
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.click()
                dayEditorStart = HabitStats.today()
                showingDayEditor = true
            } label: {
                Image(systemName: "calendar")
            }
            .accessibilityLabel("Day editor")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.click()
                showingStats = true
            } label: {
                Image(systemName: "chart.bar.xaxis")
            }
            .accessibilityLabel("Stats")
        }
    }

    private var profileGlyph: some View {
        Group {
            if let url = auth.photoURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(.circle)
    }

    private var addButton: some View {
        Button {
            Haptics.success()
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.glassProminent)
        .clipShape(.circle)
        .padding(.trailing, 22)
        .padding(.bottom, 24)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = vm.habits
        reordered.move(fromOffsets: source, toOffset: destination)
        vm.persistOrder(reordered)
    }

    /// Day-rollover review: the first time the app loads on a *new* logical day,
    /// if a positive habit was actually due yesterday, slide up the Day editor
    /// pre-set to yesterday so the user can confirm / back-fill it. At most once
    /// per launch. Mirrors Android's `maybeRunDayReview`.
    private func maybeRunDayReview() {
        guard !dayReviewChecked, auth.isSignedIn else { return }
        dayReviewChecked = true
        let todayStr = HabitStats.todayStr()
        let last = preferences.lastActiveDay
        preferences.lastActiveDay = todayStr
        guard let last, last != todayStr else { return }
        let yesterday = HabitStats.addDays(HabitStats.today(), -1)
        let reviewable = vm.habits.contains { h in
            !h.negative && HabitStats.isScheduledOn(h, yesterday) &&
                (h.createdAtDate.map { $0 <= yesterday } ?? false)
        }
        guard reviewable else { return }
        dayEditorStart = yesterday
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingDayEditor = true
        }
    }
}

#Preview {
    MainView()
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
