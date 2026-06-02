import SwiftUI
import AuthenticationServices

/// Sign-in screen. App Store Review Guideline 4.8 requires Sign in with Apple
/// alongside any third-party social login (Google) on iOS — both buttons here
/// are mandatory.
struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.30),
                        Color(.systemBackground),
                        Color.accentColor.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer(minLength: geo.size.height * 0.18)

                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 14) {
                            Image(systemName: "leaf.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 88, height: 88)
                                .foregroundStyle(.tint)
                                .glassEffect(in: .circle)

                            Text("Pathivu")
                                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            Text("Build the habits that build you.\nOne calm check-off a day.")
                                .font(.system(.body, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 36))
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 12) {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { _ in },
                            onCompletion: { _ in /* handled by AuthService */ }
                        )
                        .signInWithAppleButtonStyle(
                            UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
                        )
                        .frame(height: 54)
                        .clipShape(.capsule)
                        .overlay(
                            Button {
                                Task { await runAppleSignIn() }
                            } label: {
                                Color.clear
                            }
                            .accessibilityLabel("Sign in with Apple")
                        )
                        .disabled(isWorking)

                        Button {
                            Task { await runGoogleSignIn() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 22, weight: .medium))
                                Text("Sign in with Google")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                        .disabled(isWorking)

                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }

                        Text("By signing in you accept our Privacy Policy.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 24)
                }
            }
        }
        .overlay(alignment: .center) {
            if isWorking {
                ProgressView()
                    .padding(20)
                    .glassEffect(in: .circle)
            }
        }
    }

    private func runAppleSignIn() async {
        isWorking = true
        errorMessage = nil
        do {
            try await auth.signInWithApple()
            Haptics.success()
        } catch {
            errorMessage = friendlyMessage(for: error)
            Haptics.error()
        }
        isWorking = false
    }

    private func runGoogleSignIn() async {
        isWorking = true
        errorMessage = nil
        do {
            let presenter = topViewController()
            try await auth.signInWithGoogle(presenting: presenter)
            Haptics.success()
        } catch {
            errorMessage = friendlyMessage(for: error)
            Haptics.error()
        }
        isWorking = false
    }

    private func friendlyMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue { return "" }
        return error.localizedDescription
    }

    private func topViewController() -> UIViewController {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return UIViewController() }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

#Preview {
    SignInView()
        .environment(AuthService.shared)
}
