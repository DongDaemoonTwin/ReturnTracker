package com.returntracker.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.returntracker.android.domain.CurrencyFormatter
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

private const val MILLIS_PER_DAY = 86_400_000L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemSheet(
    onDismiss: () -> Unit,
    onAddItem: (AddReturnItemInput, (Result<Unit>) -> Unit) -> Unit,
) {
    val initialPurchaseDate = remember { LocalDate.now() }
    var productName by rememberSaveable { mutableStateOf("") }
    var storeName by rememberSaveable { mutableStateOf("") }
    var priceText by rememberSaveable { mutableStateOf("") }
    var purchaseEpochDay by rememberSaveable { mutableLongStateOf(initialPurchaseDate.toEpochDay()) }
    var deadlineEpochDay by rememberSaveable { mutableLongStateOf(initialPurchaseDate.plusDays(14).toEpochDay()) }
    var orderNumber by rememberSaveable { mutableStateOf("") }
    var note by rememberSaveable { mutableStateOf("") }
    var selectingDate by rememberSaveable { mutableStateOf<DateField?>(null) }
    var isSaving by rememberSaveable { mutableStateOf(false) }
    var saveError by rememberSaveable { mutableStateOf<String?>(null) }

    val normalizedProductName = productName.trim()
    val normalizedStoreName = storeName.trim()
    val parsedPrice = CurrencyFormatter.parseWon(priceText)
    val canSave = normalizedProductName.isNotEmpty() &&
        normalizedStoreName.isNotEmpty() &&
        parsedPrice != null &&
        deadlineEpochDay >= purchaseEpochDay &&
        !isSaving

    ModalBottomSheet(onDismissRequest = { if (!isSaving) onDismiss() }) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("상품 추가", fontWeight = FontWeight.Bold)
                TextButton(onClick = onDismiss, enabled = !isSaving) {
                    Text("취소")
                }
            }

            OutlinedTextField(
                value = productName,
                onValueChange = { productName = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("상품명") },
                singleLine = true,
            )
            OutlinedTextField(
                value = storeName,
                onValueChange = { storeName = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("구매처") },
                singleLine = true,
            )
            OutlinedTextField(
                value = priceText,
                onValueChange = { priceText = it.filter(Char::isDigit) },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("구매 가격") },
                suffix = { Text("원") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
            )

            DateFieldButton(
                label = "구매일",
                date = LocalDate.ofEpochDay(purchaseEpochDay),
                onClick = { selectingDate = DateField.PURCHASE },
            )
            DateFieldButton(
                label = "반품 마감일",
                date = LocalDate.ofEpochDay(deadlineEpochDay),
                onClick = { selectingDate = DateField.DEADLINE },
            )

            OutlinedTextField(
                value = orderNumber,
                onValueChange = { orderNumber = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("주문번호 (선택)") },
                singleLine = true,
            )
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("메모 (선택)") },
                minLines = 2,
                maxLines = 5,
            )

            Button(
                onClick = {
                    val price = parsedPrice ?: return@Button
                    isSaving = true
                    onAddItem(
                        AddReturnItemInput(
                            productName = normalizedProductName,
                            storeName = normalizedStoreName,
                            priceWon = price,
                            purchaseDate = LocalDate.ofEpochDay(purchaseEpochDay),
                            returnDeadline = LocalDate.ofEpochDay(deadlineEpochDay),
                            orderNumber = orderNumber.trim().ifEmpty { null },
                            note = note.trim().ifEmpty { null },
                        ),
                    ) { result ->
                        result.onSuccess { onDismiss() }
                            .onFailure { error ->
                                isSaving = false
                                saveError = error.localizedMessage ?: "알 수 없는 오류가 발생했습니다."
                            }
                    }
                },
                enabled = canSave,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isSaving) "저장 중…" else "저장")
            }
            Spacer(modifier = Modifier.height(12.dp))
        }
    }

    selectingDate?.let { field ->
        ReturnDatePickerDialog(
            initialDate = LocalDate.ofEpochDay(
                if (field == DateField.PURCHASE) purchaseEpochDay else deadlineEpochDay,
            ),
            minimumDate = if (field == DateField.DEADLINE) {
                LocalDate.ofEpochDay(purchaseEpochDay)
            } else {
                null
            },
            onDismiss = { selectingDate = null },
            onConfirm = { selectedDate ->
                when (field) {
                    DateField.PURCHASE -> {
                        purchaseEpochDay = selectedDate.toEpochDay()
                        if (deadlineEpochDay < purchaseEpochDay) {
                            deadlineEpochDay = selectedDate.plusDays(14).toEpochDay()
                        }
                    }
                    DateField.DEADLINE -> deadlineEpochDay = selectedDate.toEpochDay()
                }
                selectingDate = null
            },
        )
    }

    saveError?.let { message ->
        AlertDialog(
            onDismissRequest = { saveError = null },
            confirmButton = {
                TextButton(onClick = { saveError = null }) {
                    Text("확인")
                }
            },
            title = { Text("저장할 수 없습니다") },
            text = { Text(message) },
        )
    }
}

@Composable
private fun DateFieldButton(
    label: String,
    date: LocalDate,
    onClick: () -> Unit,
) {
    val formatter = remember {
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.KOREA)
    }

    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.Start) {
            Text(label)
            Text(formatter.format(date), fontWeight = FontWeight.SemiBold)
        }
        Icon(Icons.Outlined.CalendarMonth, contentDescription = null)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReturnDatePickerDialog(
    initialDate: LocalDate,
    minimumDate: LocalDate?,
    onDismiss: () -> Unit,
    onConfirm: (LocalDate) -> Unit,
) {
    val selectableDates = remember(minimumDate) {
        object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                minimumDate == null || utcTimeMillis >= minimumDate.toEpochDay() * MILLIS_PER_DAY
        }
    }
    val state = androidx.compose.material3.rememberDatePickerState(
        initialSelectedDateMillis = initialDate.toEpochDay() * MILLIS_PER_DAY,
        selectableDates = selectableDates,
    )

    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(
                onClick = {
                    state.selectedDateMillis?.let { millis ->
                        onConfirm(
                            Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate(),
                        )
                    }
                },
                enabled = state.selectedDateMillis != null,
            ) {
                Text("확인")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("취소")
            }
        },
    ) {
        DatePicker(state = state)
    }
}

private enum class DateField {
    PURCHASE,
    DEADLINE,
}
