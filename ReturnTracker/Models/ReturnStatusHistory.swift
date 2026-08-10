import Foundation
import SwiftData

@Model
final class ReturnStatusHistory {
    @Attribute(.unique) var id: UUID
    var itemID: UUID
    var statusRawValue: String
    var changedAt: Date

    init(
        id: UUID = UUID(),
        itemID: UUID,
        status: ReturnStatus,
        changedAt: Date = .now
    ) {
        self.id = id
        self.itemID = itemID
        self.statusRawValue = status.rawValue
        self.changedAt = changedAt
    }

    var status: ReturnStatus {
        ReturnStatus(rawValue: statusRawValue) ?? .keeping
    }
}
