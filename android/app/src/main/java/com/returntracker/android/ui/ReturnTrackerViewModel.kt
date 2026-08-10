package com.returntracker.android.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.returntracker.android.data.ReturnItem
import com.returntracker.android.data.ReturnItemRepository
import com.returntracker.android.domain.ReturnStatus
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

data class AddReturnItemInput(
    val productName: String,
    val storeName: String,
    val priceWon: Long,
    val purchaseDate: LocalDate,
    val returnDeadline: LocalDate,
    val orderNumber: String?,
    val note: String?,
)

class ReturnTrackerViewModel(
    private val repository: ReturnItemRepository,
) : ViewModel() {
    val items: Flow<List<ReturnItem>> = repository.items

    fun addItem(
        input: AddReturnItemInput,
        onResult: (Result<Unit>) -> Unit,
    ) {
        viewModelScope.launch {
            val result = runCatching {
                repository.insert(
                    ReturnItem(
                        productName = input.productName,
                        storeName = input.storeName,
                        priceWon = input.priceWon,
                        purchaseEpochDay = input.purchaseDate.toEpochDay(),
                        returnDeadlineEpochDay = input.returnDeadline.toEpochDay(),
                        orderNumber = input.orderNumber,
                        note = input.note,
                        statusRawValue = ReturnStatus.KEEPING.name,
                    ),
                )
            }
            onResult(result)
        }
    }

    companion object {
        fun factory(repository: ReturnItemRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    require(modelClass.isAssignableFrom(ReturnTrackerViewModel::class.java))
                    return ReturnTrackerViewModel(repository) as T
                }
            }
    }
}
