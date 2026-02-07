import Foundation
import UserNotifications

final class TaskNotificationManager {
    static let shared = TaskNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private var didRequestAuthorization = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func syncReminder(for task: AgencyTask) async {
        if task.isDone || task.dueDate == nil {
            cancelReminder(for: task)
            return
        }
        await scheduleReminder(for: task)
    }

    func scheduleReminder(for task: AgencyTask) async {
        guard let dueDate = task.dueDate else { return }
        guard dueDate > Date().addingTimeInterval(60) else { return }

        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = task.content
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: task),
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: task)])
        try? await center.add(request)
    }

    func cancelReminder(for task: AgencyTask) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: task)])
    }

    private func notificationIdentifier(for task: AgencyTask) -> String {
        "task-reminder-\(task.id.uuidString)"
    }
}
