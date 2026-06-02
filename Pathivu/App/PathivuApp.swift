import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UserNotifications

@main
struct PathivuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth = AuthService.shared
    @State private var preferences = Preferences.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(preferences)
                .preferredColorScheme(preferences.appearance.colorScheme)
                .fontDesign(preferences.useGoogleFont ? .rounded : .default)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationScheduler.configureCategories()
        Preferences.shared.syncStatsConfig()
        return true
    }

    // Google Sign-In URL callbacks are forwarded via SwiftUI's `.onOpenURL`
    // in PathivuApp — no UIApplicationDelegate URL hook needed. The legacy
    // `application(_:open:options:)` method is deprecated in iOS 26.
}
