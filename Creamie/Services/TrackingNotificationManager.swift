import Foundation
import UserNotifications
import UIKit

/// Manages user notifications for tracking events.
/// Uses local notifications for background and published state for foreground alerts.
@MainActor
class TrackingNotificationManager: ObservableObject {

    // MARK: - Published State (for foreground UI banners/alerts)

    /// Current notification to display in the UI. Set to nil after the view dismisses it.
    @Published var activeNotification: TrackingNotification?

    struct TrackingNotification: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let kind: Kind

        enum Kind: Equatable {
            case info
            case warning
            case error
        }
    }

    // MARK: - Notification Permission

    /// Request notification permission (call once, e.g. on first tracking enable).
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("⚠️ Notification permission error: \(error.localizedDescription)")
            }
            print("🔔 Notification permission granted: \(granted)")
        }
    }

    // MARK: - Public Notification Triggers

    func notifyTrackingStarted(dogName: String?) {
        let name = dogName ?? "your dog"
        post(title: "Tracking Started",
             message: "Location tracking is now active for \(name).",
             kind: .info)
    }

    func notifyTrackingStopped(dogName: String?) {
        let name = dogName ?? "your dog"
        post(title: "Tracking Stopped",
             message: "Location tracking has been stopped for \(name).",
             kind: .info)
    }

    func notifyPermissionRevoked() {
        post(title: "Location Permission Required",
             message: "Location access was revoked. Please enable it in Settings to continue tracking.",
             kind: .warning)
    }

    func notifyPersistentError(detail: String? = nil) {
        let msg = detail ?? "Repeated errors occurred while updating location. Tracking will continue to retry."
        post(title: "Tracking Issue",
             message: msg,
             kind: .error)
    }

    // MARK: - Private Helpers

    private func post(title: String, message: String, kind: TrackingNotification.Kind) {
        let notification = TrackingNotification(title: title, message: message, kind: kind)

        // Foreground: publish for UI
        if UIApplication.shared.applicationState == .active {
            activeNotification = notification
        } else {
            // Background: schedule a local notification
            scheduleLocalNotification(title: title, body: message)
        }
    }

    private func scheduleLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule local notification: \(error.localizedDescription)")
            }
        }
    }
}
