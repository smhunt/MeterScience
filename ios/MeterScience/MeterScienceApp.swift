import SwiftUI
import UserNotifications

@main
struct MeterScienceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Check subscription status on app launch
                    await subscriptionManager.checkSubscriptionStatus()

                    // Check notification authorization status
                    await PushNotificationManager.shared.checkAuthorizationStatus()
                }
        }
    }
}

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}
