import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import SwiftUI
import UIKit

/// Wraps FirebaseAuth and exposes Sign in with Apple + Google Sign-In. Both
/// providers are required on iOS — Apple's App Store Review Guideline 4.8
/// mandates Sign in with Apple alongside any third-party social login.
@Observable
@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()

    private(set) var user: User?
    private(set) var isInitialized = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var appleContinuation: CheckedContinuation<Void, Error>?

    var isSignedIn: Bool { user != nil }
    var displayName: String? { user?.displayName }
    var email: String? { user?.email }
    var photoURL: URL? { user?.photoURL }
    var uid: String? { user?.uid }

    override init() {
        super.init()
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isInitialized = true
            }
        }
    }
    // No deinit — AuthService.shared is a process-lifetime singleton.

    // MARK: - Sign out
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        AppAnalytics.authSignOut()
    }

    // MARK: - Delete account
    /// Deletes the Firebase Auth user and best-effort wipes their Firestore
    /// data. Required by App Store Guideline 5.1.1(v).
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthError.notSignedIn }
        let uid = user.uid

        do {
            try await FirestoreService.shared.deleteAllUserData(uid: uid)
        } catch {
            // Log but continue — auth-level delete is the legally required step.
        }

        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
        AppAnalytics.authSignOut()
    }

    // MARK: - Google
    func signInWithGoogle(presenting: UIViewController) async throws {
        guard let clientID = FirebaseAuth.Auth.auth().app?.options.clientID else {
            throw AuthError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        _ = try await Auth.auth().signIn(with: credential)
        AppAnalytics.authSignIn(provider: "google")
    }

    // MARK: - Apple
    func signInWithApple() async throws {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.appleContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers (Apple spec)
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple delegate
extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            if let window = scenes
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: \.isKeyWindow) {
                return window
            }
            if let window = scenes.flatMap(\.windows).first {
                return window
            }
            if let scene = scenes.first {
                return UIWindow(windowScene: scene)
            }
            preconditionFailure("Sign in with Apple presentationAnchor requested with no UIWindowScene available")
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            await finishAppleSignIn(authorization: authorization)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.appleContinuation?.resume(throwing: error)
            self.appleContinuation = nil
        }
    }

    @MainActor
    private func finishAppleSignIn(authorization: ASAuthorization) async {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce,
            let appleIDToken = appleIDCredential.identityToken,
            let idTokenString = String(data: appleIDToken, encoding: .utf8)
        else {
            appleContinuation?.resume(throwing: AuthError.missingIDToken)
            appleContinuation = nil
            return
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        do {
            _ = try await Auth.auth().signIn(with: credential)
            AppAnalytics.authSignIn(provider: "apple")
            appleContinuation?.resume(returning: ())
        } catch {
            appleContinuation?.resume(throwing: error)
        }
        appleContinuation = nil
    }
}

enum AuthError: LocalizedError {
    case missingClientID
    case missingIDToken
    case notSignedIn
    var errorDescription: String? {
        switch self {
        case .missingClientID: return "Firebase client ID is missing. Did you add GoogleService-Info.plist?"
        case .missingIDToken: return "Sign-in token missing — try again."
        case .notSignedIn: return "You're not signed in."
        }
    }
}
