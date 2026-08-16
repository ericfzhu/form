import Foundation
import UIKit
import UserNotifications

@MainActor
final class RestFeedbackService {
    static let shared = RestFeedbackService()

    private let notificationIdentifier = "form-rest-complete"
    private var schedulingTask: Task<Void, Never>?

    private init() {}

    func schedule(end: Date, exerciseName: String?) {
        schedulingTask?.cancel()
        let delay = end.timeIntervalSinceNow
        guard delay > 0 else {
            finishInForeground()
            return
        }

        schedulingTask = Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let authorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                authorized = true
            case .notDetermined:
                authorized = (try? await center.requestAuthorization(
                    options: [.alert, .sound]
                )) ?? false
            case .denied:
                authorized = false
            @unknown default:
                authorized = false
            }

            guard !Task.isCancelled, authorized else { return }
            center.removePendingNotificationRequests(
                withIdentifiers: [notificationIdentifier]
            )

            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = exerciseName.map {
                "Continue with \($0)."
            } ?? "Continue your session."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, end.timeIntervalSinceNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancel() {
        schedulingTask?.cancel()
        schedulingTask = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
    }

    func finishInForeground() {
        cancel()
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
