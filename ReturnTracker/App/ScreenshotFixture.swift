import Foundation
import SwiftData

enum ScreenshotFixtureScreen: String {
    case home
    case add
    case detail
}

enum ScreenshotFixture {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    static var screen: ScreenshotFixtureScreen {
        value(for: "--screen").flatMap(ScreenshotFixtureScreen.init(rawValue:)) ?? .home
    }

    static var usesSampleItems: Bool {
        value(for: "--fixture") == "sample"
    }

    @MainActor
    static func prepare(in modelContext: ModelContext) throws {
        for item in try modelContext.fetch(FetchDescriptor<ReturnItem>()) {
            modelContext.delete(item)
        }

        for history in try modelContext.fetch(FetchDescriptor<ReturnStatusHistory>()) {
            modelContext.delete(history)
        }

        guard usesSampleItems else {
            try modelContext.save()
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)

        let urgent = ReturnItem(
            productName: "Nike Air Max 90",
            storeName: "무신사",
            price: 129_000,
            purchaseDate: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
            returnDeadline: calendar.date(byAdding: .day, value: 2, to: today) ?? today,
            createdAt: .now
        )

        let refundPending = ReturnItem(
            productName: "Sony 무선 헤드폰",
            storeName: "쿠팡",
            price: 349_000,
            purchaseDate: calendar.date(byAdding: .day, value: -12, to: today) ?? today,
            returnDeadline: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
            orderNumber: "RT-2026-0810",
            note: "반품 송장 보관 중",
            status: .refundPending,
            createdAt: calendar.date(byAdding: .minute, value: -1, to: .now) ?? .now
        )

        let recent = ReturnItem(
            productName: "리넨 오버핏 셔츠",
            storeName: "29CM",
            price: 79_000,
            purchaseDate: today,
            returnDeadline: calendar.date(byAdding: .day, value: 7, to: today) ?? today,
            status: .keeping,
            createdAt: calendar.date(byAdding: .minute, value: -2, to: .now) ?? .now
        )

        modelContext.insert(urgent)
        modelContext.insert(refundPending)
        modelContext.insert(recent)

        let shippedAt = calendar.date(byAdding: .day, value: -5, to: .now) ?? .now
        modelContext.insert(
            ReturnStatusHistory(
                itemID: refundPending.id,
                status: .shipped,
                changedAt: shippedAt
            )
        )
        modelContext.insert(
            ReturnStatusHistory(
                itemID: refundPending.id,
                status: .refundPending,
                changedAt: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now
            )
        )

        try modelContext.save()
    }

    private static func value(for key: String) -> String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("\(key)=") }?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init)
    }
}
