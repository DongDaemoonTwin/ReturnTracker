package com.returntracker.android.data

import com.returntracker.android.email.EmailPurchaseCandidate
import com.returntracker.android.domain.ReturnStatus
import kotlinx.coroutines.flow.Flow

class ReturnItemRepository(
    private val dao: ReturnItemDao,
) {
    val items: Flow<List<ReturnItem>> = dao.observeAll()

    suspend fun insert(item: ReturnItem) = dao.insert(item)

    suspend fun importGmailCandidates(candidates: List<EmailPurchaseCandidate>): Int {
        var importedCount = 0
        candidates.forEach { candidate ->
            if (!dao.containsSourceMessage(candidate.sourceMessageId)) {
                dao.insert(
                    ReturnItem(
                        productName = candidate.productName,
                        storeName = candidate.storeName,
                        priceWon = candidate.priceWon,
                        purchaseEpochDay = candidate.purchaseDate.toEpochDay(),
                        returnDeadlineEpochDay = candidate.returnDeadline.toEpochDay(),
                        orderNumber = candidate.orderNumber,
                        note = candidate.note,
                        statusRawValue = ReturnStatus.RETURN_PLANNED.name,
                        sourceRawValue = ReturnItemSource.GMAIL.name,
                        sourceMessageId = candidate.sourceMessageId,
                        needsReview = candidate.needsReview,
                    ),
                )
                importedCount += 1
            }
        }
        return importedCount
    }
}
