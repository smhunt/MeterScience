import Foundation
import UserNotifications
import UIKit

/// Manages push notifications for MeterScience
/// Handles permission requests, device token registration, and notification handling
@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var isAuthorized = false
    @Published var deviceToken: String?
    @Published var pendingNotification: NotificationPayload?

    private let apiService = APIService.shared

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission & Registration

    /// Request notification permissions and register for remote notifications
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    /// Register for remote notifications (must be called on main thread)
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Device Token Handling

    /// Called when APNs registration succeeds
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Task { @MainActor in
            self.deviceToken = tokenString
            await self.registerDeviceWithBackend(token: tokenString)
        }
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    /// Register device token with backend
    private func registerDeviceWithBackend(token: String) async {
        do {
            let device = UIDevice.current
            let request = RegisterDeviceRequest(
                deviceToken: token,
                deviceName: device.name,
                deviceModel: device.model,
                osVersion: device.systemVersion
            )

            _ = try await apiService.registerDevice(request)
            print("Device registered for push notifications")
        } catch {
            print("Failed to register device with backend: \(error)")
        }
    }

    // MARK: - Notification Handling

    /// Handle notification received while app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        processNotificationPayload(userInfo)
    }

    /// Handle notification tap that opened the app
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        processNotificationPayload(userInfo)
    }

    /// Process notification payload and navigate accordingly
    private func processNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["notification_type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return
        }

        let payload = NotificationPayload(
            type: type,
            data: userInfo as? [String: Any] ?? [:]
        )

        // Set pending notification for UI to handle
        pendingNotification = payload

        // Post notification for any observers
        NotificationCenter.default.post(
            name: .didReceivePushNotification,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    /// Clear pending notification after handling
    func clearPendingNotification() {
        pendingNotification = nil
    }

    // MARK: - Badge Management

    /// Update app badge count
    func setBadgeCount(_ count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            print("Failed to set badge count: \(error)")
        }
    }

    /// Clear app badge
    func clearBadge() async {
        await setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Called when notification is received while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            self.handleForegroundNotification(notification)
        }

        // Show banner and play sound even when in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when user taps on notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationResponse(response)
        }
        completionHandler()
    }
}

// MARK: - Supporting Types

/// Types of push notifications from the backend
enum NotificationType: String, Codable {
    case readingVerified = "reading_verified"
    case verificationNeeded = "verification_needed"
    case streakReminder = "streak_reminder"
    case streakMilestone = "streak_milestone"
    case badgeEarned = "badge_earned"
    case levelUp = "level_up"
    case campaignUpdate = "campaign_update"
    case weeklyDigest = "weekly_digest"
}

/// Parsed notification payload
struct NotificationPayload: Identifiable {
    let id = UUID()
    let type: NotificationType
    let data: [String: Any]

    var meterName: String? { data["meter_name"] as? String }
    var readingValue: String? { data["reading_value"] as? String }
    var pendingCount: Int? { data["pending_count"] as? Int }
    var currentStreak: Int? { data["current_streak"] as? Int }
    var streakDays: Int? { data["streak_days"] as? Int }
    var xpBonus: Int? { data["xp_bonus"] as? Int }
    var badgeName: String? { data["badge_name"] as? String }
    var newLevel: Int? { data["new_level"] as? Int }
    var campaignName: String? { data["campaign_name"] as? String }
    var readingsCount: Int? { data["readings_count"] as? Int }
    var xpEarned: Int? { data["xp_earned"] as? Int }
}

/// Request to register device with backend
struct RegisterDeviceRequest: Codable {
    let deviceToken: String
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
    }
}

/// Response from device registration
struct DeviceResponse: Codable {
    let id: String
    let deviceToken: String
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let createdAt: String
    let lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceToken = "device_token"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didReceivePushNotification = Notification.Name("didReceivePushNotification")
}
