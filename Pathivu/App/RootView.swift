import SwiftUI
import LocalAuthentication

/// Top-level switcher: App Lock gate (if biometric enabled), the sign-in screen
/// (if unauthenticated), or the Main screen.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(Preferences.self) private var preferences

    @State private var didUnlock = false
    @State private var requiresUnlock = false

    var body: some View {
        ZStack {
            if !auth.isInitialized {
                LaunchSplash()
            } else if requiresUnlock && !didUnlock {
                AppLockGate(onUnlock: { didUnlock = true })
            } else if !auth.isSignedIn {
                SignInView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                MainView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: auth.isSignedIn)
        .animation(.smooth(duration: 0.3), value: didUnlock)
        .task {
            requiresUnlock = preferences.biometricEnabled && BiometricAuth.isAvailable
        }
    }
}

private struct LaunchSplash: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.tint)
                Text("Pathivu")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            }
        }
    }
}

private struct AppLockGate: View {
    var onUnlock: () -> Void
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: BiometricAuth.biometryType == .faceID ? "faceid" : "touchid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)
                Text("Pathivu is locked")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                Text("Authenticate with \(BiometricAuth.displayName) to continue.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Unlock") {
                    Task {
                        if await BiometricAuth.authenticate() {
                            Haptics.success()
                            onUnlock()
                        } else {
                            Haptics.error()
                            failed = true
                        }
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .padding(.top, 8)

                if failed {
                    Text("Authentication failed — try again")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(36)
        }
        .task {
            if await BiometricAuth.authenticate() {
                Haptics.success()
                onUnlock()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AuthService.shared)
        .environment(Preferences.shared)
}
