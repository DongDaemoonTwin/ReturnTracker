import Foundation

enum ReturnStatus: String, CaseIterable, Codable, Identifiable {
    case keeping
    case returnPlanned
    case returnRequested
    case shipped
    case refundPending
    case refunded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keeping:
            "보유 중"
        case .returnPlanned:
            "반품 예정"
        case .returnRequested:
            "반품 신청"
        case .shipped:
            "반품 발송"
        case .refundPending:
            "환불 대기"
        case .refunded:
            "환불 완료"
        }
    }

    var symbolName: String {
        switch self {
        case .keeping:
            "shippingbox"
        case .returnPlanned:
            "arrow.uturn.backward"
        case .returnRequested:
            "doc.text"
        case .shipped:
            "truck.box"
        case .refundPending:
            "clock.arrow.circlepath"
        case .refunded:
            "checkmark.circle.fill"
        }
    }

    var needsDeadlineReminders: Bool {
        switch self {
        case .keeping, .returnPlanned, .returnRequested:
            true
        case .shipped, .refundPending, .refunded:
            false
        }
    }
}
