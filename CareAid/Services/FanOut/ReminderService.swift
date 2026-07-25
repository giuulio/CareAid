import Foundation
import UserNotifications

/// Local notifications for approved tasks and timers.
///
/// Local, not push — §10 rules out a server pushing anything, and a reminder
/// that fires without a network round trip is one less thing to fail on stage.
struct ReminderService {

    enum ReminderError: LocalizedError {
        case notPermitted
        case inThePast

        var errorDescription: String? {
            switch self {
            case .notPermitted:
                "CareAid needs permission to send reminders. Settings › CareAid › Notifications."
            case .inThePast:
                "That time has already passed."
            }
        }
    }

    func requestAccess() async throws {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw ReminderError.notPermitted }
    }

    func schedule(task payload: TaskPayload, id: UUID) async throws {
        // A task with no due date is still worth keeping — it just doesn't ring.
        guard let dueAt = payload.dueAt else { return }
        try await schedule(id: id, title: payload.title, body: payload.why, at: dueAt)
    }

    func schedule(timer payload: TimerPayload, id: UUID) async throws {
        try await schedule(id: id, title: payload.label, body: nil, at: payload.fireAt)
    }

    private func schedule(id: UUID, title: String, body: String?, at date: Date) async throws {
        guard date > .now else { throw ReminderError.inThePast }
        try await requestAccess()

        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        content.sound = .default

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )

        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                // Keyed on the artifact id, so approving twice replaces rather
                // than stacking two identical reminders.
                identifier: id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        )
    }
}
