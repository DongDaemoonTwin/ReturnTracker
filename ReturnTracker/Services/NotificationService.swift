import Foundation
import UserNotifications

enum ReturnNotificationSchedule {
    static let reminderOffsets = [3, 1, 0]

    static func reminderDates(
        deadline: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        deliveryHour: Int = 9
    ) -> [(offset: Int, date: Date)] {
        let deadlineDay = calendar.startOfDay(for: deadline)

        return reminderOffsets.compactMap { offset in
            guard
                let reminderDay = calendar.date(byAdding: .day, value: -offset, to: deadlineDay),
                let reminderDate = calendar.date(bySettingHour: deliveryHour, minute: 0, second: 0, of: reminderDay),
                reminderDate > now
            else {
                return nil
            }

            return (offset, reminderDate)
        }
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        let status = await authorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func schedule(for item: ReturnItem, now: Date = .now) async {
        cancel(itemID: item.id)
        guard item.status.needsDeadlineReminders else { return }

        let dates = ReturnNotificationSchedule.reminderDates(
            deadline: item.returnDeadline,
            now: now
        )

        for reminder in dates {
            let content = UNMutableNotificationContent()
            content.title = reminder.offset == 0 ? "오늘 반품 마감" : "반품 마감 D-\(reminder.offset)"
            content.body = "\(item.productName)의 반품 기한을 확인하세요."
            content.sound = .default
            content.userInfo = ["itemID": item.id.uuidString]

            let components = Calendar.autoupdatingCurrent.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(itemID: item.id, offset: reminder.offset),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    func cancel(itemID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: ReturnNotificationSchedule.reminderOffsets.map {
                identifier(itemID: itemID, offset: $0)
            }
        )
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func identifier(itemID: UUID, offset: Int) -> String {
        "return-item-\(itemID.uuidString)-d\(offset)"
    }
}
