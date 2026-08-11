import Foundation

struct EmailMessageSnapshot {
    let id: String
    let subject: String
    let from: String
    let receivedAt: Date
    let body: String
}

struct EmailPurchaseCandidate {
    let sourceMessageID: String
    let productName: String
    let storeName: String
    let price: Decimal
    let purchaseDate: Date
    let returnDeadline: Date
    let orderNumber: String?
    let note: String
    let needsReview: Bool
}

enum PurchaseEmailParser {
    static func parse(
        _ message: EmailMessageSnapshot,
        calendar: Calendar = .current
    ) -> EmailPurchaseCandidate? {
        let text = "\(message.subject)\n\(message.body)"
        guard text.containsMatch("(주문|결제|구매|영수증|order|receipt|payment)"),
              !message.subject.containsMatch("(주문|결제).{0,12}(취소|환불).{0,12}(완료|처리)") else {
            return nil
        }

        let purchaseDate = calendar.startOfDay(for: message.receivedAt)
        let explicitDeadline = deadline(in: text, calendar: calendar)
        let policyDays = text.firstCapturedInt(
            "(?:반품|return).{0,40}(?:수령|배송(?:\\s*완료)?|purchase)?.{0,20}(\\d{1,2})일\\s*(?:이내|동안|까지)"
        )
        let estimatedDays = policyDays ?? defaultReturnDays
        let returnDeadline = explicitDeadline
            ?? calendar.date(byAdding: .day, value: estimatedDays, to: purchaseDate)
            ?? purchaseDate
        let deadlineWasEstimated = explicitDeadline == nil

        let extractedProductName = text.firstCapturedString(
            "(?:상품명|주문\\s?상품|product(?:\\sname)?)\\s*[:：]\\s*([^\\r\\n|]{2,100})"
        )?.cleaned
        let subjectProductName = cleanSubject(message.subject)
        let productName = extractedProductName
            ?? (subjectProductName.count >= 2 ? subjectProductName : nil)
            ?? "상품명 확인 필요"
        let price = findPrice(in: text)
        let needsReview = deadlineWasEstimated || productName == "상품명 확인 필요" || price == 0

        var notes = ["Gmail 자동 등록"]
        if deadlineWasEstimated {
            if let policyDays {
                notes.append("메일의 \(policyDays)일 정책으로 마감일 추정")
            } else {
                notes.append("반품 마감일을 구매일 기준 \(defaultReturnDays)일로 추정")
            }
        }
        if needsReview {
            notes.append("상품 정보 확인 필요")
        }

        return EmailPurchaseCandidate(
            sourceMessageID: message.id,
            productName: productName,
            storeName: storeName(from: message.from),
            price: price,
            purchaseDate: purchaseDate,
            returnDeadline: returnDeadline,
            orderNumber: text.firstCapturedString(
                "(?:주문\\s?번호|order\\s?(?:number|no\\.?|#))\\s*[:：#]?\\s*([A-Z0-9-]{5,40})"
            )?.cleaned,
            note: notes.joined(separator: " · "),
            needsReview: needsReview
        )
    }

    private static func deadline(in text: String, calendar: Calendar) -> Date? {
        let patterns = [
            "(20\\d{2})[./-]\\s*(\\d{1,2})[./-]\\s*(\\d{1,2})",
            "(20\\d{2})년\\s*(\\d{1,2})월\\s*(\\d{1,2})일"
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            for match in expression.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let lower = text.index(matchRange.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
                let upper = text.index(matchRange.upperBound, offsetBy: 60, limitedBy: text.endIndex) ?? text.endIndex
                let context = String(text[lower..<upper])
                guard context.containsMatch("반품|교환|return") else { continue }

                let numbers = (1...3).compactMap { index -> Int? in
                    guard let componentRange = Range(match.range(at: index), in: text) else { return nil }
                    return Int(text[componentRange])
                }
                guard numbers.count == 3 else { continue }
                var components = DateComponents()
                components.calendar = calendar
                components.timeZone = calendar.timeZone
                components.year = numbers[0]
                components.month = numbers[1]
                components.day = numbers[2]
                if let date = calendar.date(from: components) {
                    return calendar.startOfDay(for: date)
                }
            }
        }
        return nil
    }

    private static func findPrice(in text: String) -> Decimal {
        let patterns = [
            "(?:총\\s*(?:결제|주문)\\s*금액|결제\\s*금액|합계|total)[^0-9]{0,20}([0-9][0-9,]*)\\s*(?:원|KRW|₩)",
            "(?:₩\\s*)?([0-9][0-9,]{2,})\\s*(?:원|KRW)"
        ]
        for pattern in patterns {
            if let raw = text.firstCapturedString(pattern)?.replacingOccurrences(of: ",", with: ""),
               let value = Decimal(string: raw) {
                return value
            }
        }
        return 0
    }

    private static func cleanSubject(_ subject: String) -> String {
        subject
            .replacingMatches("^\\s*\\[[^]]+]\\s*", with: "")
            .replacingMatches(
                "(?:주문|결제|구매|영수증|order|receipt|payment).{0,20}(?:완료|확인|내역|되었습니다|received)?",
                with: ""
            )
            .replacingMatches("[-:：|]+", with: " ")
            .cleaned
    }

    private static func storeName(from: String) -> String {
        if let displayName = from.firstCapturedString("^\\s*\\\"?([^\\\"<]+)\\\"?\\s*<")?.cleaned,
           !displayName.isEmpty {
            return displayName
        }

        let domain = from.components(separatedBy: "@").last?
            .components(separatedBy: ">").first?
            .lowercased() ?? ""
        if domain.contains("coupang") { return "쿠팡" }
        if domain.contains("musinsa") { return "무신사" }
        if domain.contains("naver") { return "네이버" }
        if domain.contains("amazon") { return "Amazon" }
        if let first = domain.components(separatedBy: ".").first, !first.isEmpty {
            return first.prefix(1).uppercased() + first.dropFirst()
        }
        return "구매처 확인 필요"
    }

    private static let defaultReturnDays = 14
}

private extension String {
    var cleaned: String {
        trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'-:：")))
    }

    func containsMatch(_ pattern: String) -> Bool {
        range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    func firstCapturedString(_ pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[range])
    }

    func firstCapturedInt(_ pattern: String) -> Int? {
        firstCapturedString(pattern).flatMap(Int.init)
    }

    func replacingMatches(_ pattern: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return self
        }
        return expression.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: replacement
        )
    }
}
