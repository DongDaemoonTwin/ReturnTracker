import XCTest
@testable import ReturnTracker

final class PurchaseEmailParserTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testParsesLabelledPurchaseAndExplicitDeadline() throws {
        let candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id: "gmail-1",
                subject: "[무신사] 주문이 완료되었습니다",
                from: "무신사 <no-reply@musinsa.com>",
                receivedAt: ISO8601DateFormatter().date(from: "2026-08-10T03:00:00Z")!,
                body: """
                상품명: 오버사이즈 셔츠
                주문번호: M-12345678
                총 결제 금액: 39,900원
                반품 마감일: 2026.08.20
                """
            ),
            calendar: calendar
        )

        let unwrapped = try XCTUnwrap(candidate)
        XCTAssertEqual(unwrapped.productName, "오버사이즈 셔츠")
        XCTAssertEqual(unwrapped.storeName, "무신사")
        XCTAssertEqual(unwrapped.price, Decimal(39_900))
        XCTAssertEqual(unwrapped.orderNumber, "M-12345678")
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day], from: unwrapped.returnDeadline),
            DateComponents(year: 2026, month: 8, day: 20)
        )
        XCTAssertFalse(unwrapped.needsReview)
    }

    func testFallsBackToFourteenDaysAndFlagsReview() throws {
        let candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id: "gmail-2",
                subject: "[쿠팡] 블루투스 키보드 주문 완료",
                from: "no-reply@coupang.com",
                receivedAt: ISO8601DateFormatter().date(from: "2026-08-10T03:00:00Z")!,
                body: "결제 금액 25,000원"
            ),
            calendar: calendar
        )

        let unwrapped = try XCTUnwrap(candidate)
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day], from: unwrapped.returnDeadline),
            DateComponents(year: 2026, month: 8, day: 24)
        )
        XCTAssertTrue(unwrapped.needsReview)
        XCTAssertTrue(unwrapped.note.contains("14일"))
    }

    func testIgnoresCancelledOrderMessage() {
        let candidate = PurchaseEmailParser.parse(
            EmailMessageSnapshot(
                id: "gmail-3",
                subject: "주문 취소 처리 완료",
                from: "shop@example.com",
                receivedAt: .now,
                body: "주문번호: CANCEL-123 결제 금액: 10,000원"
            ),
            calendar: calendar
        )

        XCTAssertNil(candidate)
    }
}
