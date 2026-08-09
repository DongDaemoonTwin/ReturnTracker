import Foundation

enum CurrencyFormatter {
    private static let koreanWon: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KRW"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func won(_ amount: Decimal) -> String {
        koreanWon.string(from: amount as NSDecimalNumber) ?? "\(amount)원"
    }

    static func decimal(from input: String) -> Decimal? {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Decimal(string: digits)
    }
}

