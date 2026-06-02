import SwiftUI
import FirebaseAuth

/// Settings. Mirrors Android's `SettingsActivity`: appearance, rounded font,
/// haptics, app lock, daily reminder + time, new-day offset, start-of-week,
/// archived habits, account, and the mandatory Delete-account flow (Guideline
/// 5.1.1(v)).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var preferences

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showArchived = false
    @State private var showAbout = false
    @State private var showReminderTime = false
    @State private var reminderTime = Date()
    @State private var errorMessage: String?

    private let dayStartOffsets = Array(-3...6)
    private let weekStartOptions: [(iso: Int, label: String)] = [(1, "Monday"), (7, "Sunday"), (6, "Saturday")]

    var body: some View {
        @Bindable var prefs = preferences
        NavigationStack {
            Form {
                appearanceSection(prefs: $prefs)
                reminderSection(prefs: $prefs)
                trackingSection(prefs: $prefs)
                manageSection
                accountSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                AppAnalytics.screenSettingsOpen()
                reminderTime = timeToday(hour: preferences.notificationHour, minute: preferences.notificationMinute)
            }
            .sheet(isPresented: $showArchived) { ArchivedHabitsSheet() }
            .sheet(isPresented: $showAbout) { AboutSheet() }
            .sheet(isPresented: $showReminderTime) { reminderTimeSheet }
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { signOut() }
            } message: {
                Text("You can sign back in anytime. Your habits stay safely synced.")
            }
            .confirmationDialog("Delete account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { deleteAccount() }
            } message: {
                Text("This permanently erases your account and every habit. This can't be undone.")
            }
            .alert("Something went wrong", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections
    private func appearanceSection(prefs: Bindable<Preferences>) -> some View {
        Section("Appearance") {
            Picker("Theme", selection: prefs.appearance) {
                ForEach(Preferences.Appearance.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Rounded font", isOn: prefs.useGoogleFont)
                .onChange(of: preferences.useGoogleFont) { _, v in
                    AppAnalytics.settingFontChange(v ? "rounded" : "system")
                }
            Toggle("Haptics", isOn: prefs.hapticsEnabled)
                .onChange(of: preferences.hapticsEnabled) { _, v in
                    if v { Haptics.click() }
                    AppAnalytics.settingHapticsToggle(v)
                }
            Toggle("App Lock (Face ID / Touch ID)", isOn: prefs.biometricEnabled)
                .onChange(of: preferences.biometricEnabled) { _, v in
                    if v && !BiometricAuth.isAvailable {
                        preferences.biometricEnabled = false
                        errorMessage = "No biometric or device passcode is set up on this device."
                        return
                    }
                    AppAnalytics.settingAppLockToggle(v)
                }
        }
    }

    private func reminderSection(prefs: Bindable<Preferences>) -> some View {
        Section("Daily reminder") {
            Toggle("Remind me", isOn: prefs.remindersEnabled)
                .onChange(of: preferences.remindersEnabled) { _, v in
                    AppAnalytics.settingRemindersToggle(v)
                    Task { await rescheduleReminder() }
                }
            if preferences.remindersEnabled {
                Button {
                    reminderTime = timeToday(hour: preferences.notificationHour, minute: preferences.notificationMinute)
                    showReminderTime = true
                } label: {
                    LabeledContent("Reminder time", value: timeLabel(preferences.notificationHour, preferences.notificationMinute))
                }
                Button("Send test notification") {
                    Task { await NotificationScheduler.postTestNotification() }
                }
            }
        }
    }

    private func trackingSection(prefs: Bindable<Preferences>) -> some View {
        Section("Tracking") {
            Picker("New day starts at", selection: prefs.dayStartHour) {
                ForEach(dayStartOffsets, id: \.self) { Text(dayStartLabel($0)).tag($0) }
            }
            .onChange(of: preferences.dayStartHour) { _, v in
                preferences.syncStatsConfig()
                AppAnalytics.settingDayStartChange(v)
            }
            Picker("Start of week", selection: prefs.weekStartDay) {
                ForEach(weekStartOptions, id: \.iso) { Text($0.label).tag($0.iso) }
            }
            .onChange(of: preferences.weekStartDay) { _, v in
                preferences.syncStatsConfig()
                AppAnalytics.settingWeekStartChange(v)
            }
        }
    }

    private var manageSection: some View {
        Section {
            Button {
                AppAnalytics.screenArchivedOpen()
                showArchived = true
            } label: {
                Label("Archived habits", systemImage: "archivebox")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Signed in as", value: auth.email ?? "—")
            Button(role: .destructive) { showSignOutConfirm = true } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Delete account", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Link(destination: URL(string: "https://github.com/aarshps/pathivu-android/blob/main/PRIVACY.md")!) {
                Label("Privacy policy", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://github.com/aarshps/pathivu-android/blob/main/DATA_DELETION.md")!) {
                Label("Data deletion", systemImage: "doc.badge.gearshape")
            }
            Button {
                AppAnalytics.screenAboutOpen()
                showAbout = true
            } label: {
                Label("About Pathivu", systemImage: "info.circle")
            }
        } footer: {
            Text("Pathivu \(appVersion())")
        }
    }

    private var reminderTimeSheet: some View {
        NavigationStack {
            DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("Reminder time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                            preferences.setNotificationTime(hour: comps.hour ?? 9, minute: comps.minute ?? 0)
                            AppAnalytics.settingReminderTimeChange()
                            showReminderTime = false
                            Task { await rescheduleReminder() }
                        }
                    }
                }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: Helpers
    private func timeToday(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func timeLabel(_ hour: Int, _ minute: Int) -> String {
        timeToday(hour: hour, minute: minute).formatted(.dateTime.hour().minute())
    }

    private func dayStartLabel(_ offset: Int) -> String {
        if offset == 0 { return "Midnight (12 AM)" }
        let hour = ((offset % 24) + 24) % 24
        return timeToday(hour: hour, minute: 0).formatted(.dateTime.hour().minute())
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func rescheduleReminder() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            await NotificationScheduler.reschedule(for: [])
            return
        }
        let habits = (try? await FirestoreService.shared.fetchHabits(uid: uid)) ?? []
        await NotificationScheduler.reschedule(for: habits.filter { !$0.archived })
    }

    private func signOut() {
        do {
            try auth.signOut()
            NotificationScheduler.clearAllScheduled()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await auth.deleteAccount()
                NotificationScheduler.clearAllScheduled()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
