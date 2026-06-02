import SwiftUI

/// Shown on the home screen when the user has no active habits yet.
struct EmptyState: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(28)
                .glassEffect(in: .circle)
            Text("Plant your first habit")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Small, daily check-offs grow into\nstreaks you won't want to break.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.success()
                onAdd()
            } label: {
                Label("New habit", systemImage: "plus")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .padding(.top, 4)
        }
        .padding(36)
    }
}

#Preview {
    EmptyState(onAdd: {})
}
