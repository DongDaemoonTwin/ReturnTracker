package com.returntracker.android.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.returntracker.android.data.ReturnItem
import com.returntracker.android.data.ReturnItemRepository
import com.returntracker.android.domain.ReturnStatus
import com.returntracker.android.email.GmailApiClient
import com.returntracker.android.email.PurchaseEmailParser
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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

data class GmailSyncUiState(
    val isSyncing: Boolean = false,
    val message: String? = null,
)

class ReturnTrackerViewModel(
    private val repository: ReturnItemRepository,
    private val gmailApiClient: GmailApiClient = GmailApiClient(),
) : ViewModel() {
    val items: Flow<List<ReturnItem>> = repository.items
    private val mutableGmailSyncState = MutableStateFlow(GmailSyncUiState())
    val gmailSyncState: StateFlow<GmailSyncUiState> = mutableGmailSyncState.asStateFlow()

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

    fun beginGmailAuthorization() {
        mutableGmailSyncState.value = GmailSyncUiState(isSyncing = true)
    }

    fun gmailAuthorizationFailed(error: Throwable) {
        mutableGmailSyncState.value = GmailSyncUiState(
            message = error.localizedMessage ?: "Gmail 권한을 확인할 수 없습니다.",
        )
    }

    fun syncGmail(accessToken: String) {
        mutableGmailSyncState.value = GmailSyncUiState(isSyncing = true)
        viewModelScope.launch {
            mutableGmailSyncState.value = runCatching {
                val messages = gmailApiClient.fetchRecentPurchaseEmails(accessToken)
                val candidates = messages.mapNotNull(PurchaseEmailParser::parse)
                val imported = repository.importGmailCandidates(candidates)
                val skipped = candidates.size - imported
                GmailSyncUiState(
                    message = when {
                        messages.isEmpty() -> "최근 90일의 구매 메일을 찾지 못했습니다."
                        candidates.isEmpty() -> "구매 정보로 판별할 수 있는 메일이 없습니다."
                        skipped > 0 -> "${imported}개를 반품 대기에 추가하고, 이미 등록된 ${skipped}개는 건너뛰었습니다."
                        else -> "${imported}개를 반품 대기에 추가했습니다."
                    },
                )
            }.getOrElse { error ->
                GmailSyncUiState(
                    message = error.localizedMessage ?: "메일 동기화 중 오류가 발생했습니다.",
                )
            }
        }
    }

    fun dismissGmailSyncMessage() {
        mutableGmailSyncState.value = mutableGmailSyncState.value.copy(message = null)
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
