import Foundation

enum ReturnDeadline {
    static func daysRemaining(
        until deadline: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let deadlineDay = calendar.startOfDay(for: deadline)
        return calendar.dateComponents([.day], from: today, to: deadlineDay).day ?? 0
    }

    static func label(
        until deadline: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        switch daysRemaining(until: deadline, now: now, calendar: calendar) {
        case let days where days > 0:
            "D-\(days)"
        case 0:
            "오늘 마감"
        default:
            "기간 지남"
        }
    }

    static func needsAttention(
        deadline: Date,
        status: ReturnStatus,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard status != .refunded else { return false }
        return daysRemaining(until: deadline, now: now, calendar: calendar) <= 3
    }
}

