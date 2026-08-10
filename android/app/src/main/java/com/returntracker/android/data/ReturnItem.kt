package com.returntracker.android.data

import androidx.room.Entity
import androidx.room.Ignore
import androidx.room.PrimaryKey
import com.returntracker.android.domain.ReturnStatus
import java.time.LocalDate
import java.util.UUID

@Entity(tableName = "return_items")
data class ReturnItem(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val productName: String,
    val storeName: String,
    val priceWon: Long,
    val purchaseEpochDay: Long,
    val returnDeadlineEpochDay: Long,
    val orderNumber: String? = null,
    val note: String? = null,
    val statusRawValue: String = ReturnStatus.KEEPING.name,
    val createdAtMillis: Long = System.currentTimeMillis(),
    val updatedAtMillis: Long = System.currentTimeMillis(),
) {
    @get:Ignore
    val purchaseDate: LocalDate
        get() = LocalDate.ofEpochDay(purchaseEpochDay)

    @get:Ignore
    val returnDeadline: LocalDate
        get() = LocalDate.ofEpochDay(returnDeadlineEpochDay)

    @get:Ignore
    val status: ReturnStatus
        get() = ReturnStatus.entries.firstOrNull { it.name == statusRawValue } ?: ReturnStatus.KEEPING
}
