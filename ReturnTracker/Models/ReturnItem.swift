import Foundation
import SwiftData

@Model
final class ReturnItem {
    @Attribute(.unique) var id: UUID
    var productName: String
    var storeName: String
    var price: Decimal
    var purchaseDate: Date
    var returnDeadline: Date
    var orderNumber: String?
    var note: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var imageData: Data?
    var sourceRawValue: String = ReturnItemSource.manual.rawValue
    var sourceMessageID: String?
    var needsReview: Bool = false

    init(
        id: UUID = UUID(),
        productName: String,
        storeName: String,
        price: Decimal,
        purchaseDate: Date,
        returnDeadline: Date,
        orderNumber: String? = nil,
        note: String? = nil,
        status: ReturnStatus = .keeping,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        imageData: Data? = nil,
        source: ReturnItemSource = .manual,
        sourceMessageID: String? = nil,
        needsReview: Bool = false
    ) {
        self.id = id
        self.productName = productName
        self.storeName = storeName
        self.price = price
        self.purchaseDate = purchaseDate
        self.returnDeadline = returnDeadline
        self.orderNumber = orderNumber
        self.note = note
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.sourceRawValue = source.rawValue
        self.sourceMessageID = sourceMessageID
        self.needsReview = needsReview
    }

    var status: ReturnStatus {
        get { ReturnStatus(rawValue: statusRawValue) ?? .keeping }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var source: ReturnItemSource {
        ReturnItemSource(rawValue: sourceRawValue) ?? .manual
    }
}
