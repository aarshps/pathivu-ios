import SwiftUI

/// About Pathivu. Mirrors Android's `AboutBottomSheet`.
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "leaf.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 88, height: 88)
                        .foregroundStyle(.tint)
                        .padding(.top, 24)
                    Text("Pathivu")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("പതിവ് — \"habit / routine\"")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("A calm habit tracker from the Hora family. Build good habits, quit bad ones, and watch your streaks grow — synced across your devices and your Android phone.")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    VStack(spacing: 6) {
                        Text("Version \(version)")
                        Text("Made with care · MIT licensed")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    AboutSheet()
}
