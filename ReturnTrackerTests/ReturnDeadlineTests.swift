import XCTest
@testable import ReturnTracker

final class ReturnDeadlineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testTodayIsZeroDaysRemaining() {
        let now = date(year: 2026, month: 8, day: 9, hour: 23, minute: 50)
        let deadline = date(year: 2026, month: 8, day: 9, hour: 0, minute: 1)

        XCTAssertEqual(ReturnDeadline.daysRemaining(until: deadline, now: now, calendar: calendar), 0)
        XCTAssertEqual(ReturnDeadline.label(until: deadline, now: now, calendar: calendar), "오늘 마감")
    }

    func testTomorrowIsOneDayRemainingAcrossMidnight() {
        let now = date(year: 2026, month: 8, day: 9, hour: 23, minute: 59)
        let deadline = date(year: 2026, month: 8, day: 10, hour: 0, minute: 1)

        XCTAssertEqual(ReturnDeadline.daysRemaining(until: deadline, now: now, calendar: calendar), 1)
        XCTAssertEqual(ReturnDeadline.label(until: deadline, now: now, calendar: calendar), "D-1")
    }

    func testThreeDaysAwayNeedsAttention() {
        let now = date(year: 2026, month: 8, day: 9)
        let deadline = date(year: 2026, month: 8, day: 12)

        XCTAssertTrue(
            ReturnDeadline.needsAttention(
                deadline: deadline,
                status: .keeping,
                now: now,
                calendar: calendar
            )
        )
    }

    func testExpiredDeadline() {
        let now = date(year: 2026, month: 8, day: 9)
        let deadline = date(year: 2026, month: 8, day: 8)

        XCTAssertEqual(ReturnDeadline.daysRemaining(until: deadline, now: now, calendar: calendar), -1)
        XCTAssertEqual(ReturnDeadline.label(until: deadline, now: now, calendar: calendar), "기간 지남")
    }

    func testRefundedItemDoesNotNeedAttention() {
        XCTAssertFalse(
            ReturnDeadline.needsAttention(
                deadline: date(year: 2026, month: 8, day: 9),
                status: .refunded,
                now: date(year: 2026, month: 8, day: 9),
                calendar: calendar
            )
        )
    }

    func testPostShipmentStatusesDoNotNeedDeadlineAttention() {
        let deadline = date(year: 2026, month: 8, day: 9)
        let now = date(year: 2026, month: 8, day: 9)

        for status in [ReturnStatus.shipped, .refundPending, .refunded] {
            XCTAssertFalse(
                ReturnDeadline.needsAttention(
                    deadline: deadline,
                    status: status,
                    now: now,
                    calendar: calendar
                )
            )
        }
    }

    func testNotificationScheduleCreatesD3D1AndDeadlineAtNine() {
        let now = date(year: 2026, month: 8, day: 10, hour: 8)
        let deadline = date(year: 2026, month: 8, day: 13)

        let reminders = ReturnNotificationSchedule.reminderDates(
            deadline: deadline,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(reminders.map { $0.offset }, [3, 1, 0])
        XCTAssertEqual(calendar.component(.hour, from: reminders[0].date), 9)
        XCTAssertEqual(calendar.component(.day, from: reminders[0].date), 10)
        XCTAssertEqual(calendar.component(.day, from: reminders[1].date), 12)
        XCTAssertEqual(calendar.component(.day, from: reminders[2].date), 13)
    }

    func testNotificationScheduleSkipsPastDeliveryTime() {
        let now = date(year: 2026, month: 8, day: 10, hour: 10)
        let deadline = date(year: 2026, month: 8, day: 13)

        let reminders = ReturnNotificationSchedule.reminderDates(
            deadline: deadline,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(reminders.map { $0.offset }, [1, 0])
    }

    func testPriceParserAcceptsZeroAndFormattedLargePrice() {
        XCTAssertEqual(CurrencyFormatter.decimal(from: "0"), Decimal(0))
        XCTAssertEqual(CurrencyFormatter.decimal(from: "₩1,250,000원"), Decimal(1_250_000))
        XCTAssertNil(CurrencyFormatter.decimal(from: ""))
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
