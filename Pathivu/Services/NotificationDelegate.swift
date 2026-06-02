import Foundation
import UserNotifications

/// Routes notification interactions to analytics. The daily reminder has no
/// action buttons (matching Android) — tapping it just foregrounds the app.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            AppAnalytics.notificationTap()
        case UNNotificationDismissActionIdentifier:
            AppAnalytics.notificationDismiss()
        default:
            break
        }
        completionHandler()
    }
}
