package com.returntracker.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.HourglassTop
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.Undo
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.returntracker.android.data.ReturnItem
import com.returntracker.android.domain.CurrencyFormatter
import com.returntracker.android.domain.ReturnDeadline
import com.returntracker.android.domain.ReturnStatus
import java.time.LocalDate

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    items: List<ReturnItem>,
    onAddItem: (AddReturnItemInput, (Result<Unit>) -> Unit) -> Unit,
) {
    var isAddingItem by rememberSaveable { mutableStateOf(false) }
    var today by remember { mutableStateOf(LocalDate.now()) }
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) today = LocalDate.now()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("반품 관리") },
                actions = {
                    IconButton(onClick = { isAddingItem = true }) {
                        Icon(Icons.Default.Add, contentDescription = "상품 추가")
                    }
                },
            )
        },
    ) { padding ->
        if (items.isEmpty()) {
            EmptyState(
                modifier = Modifier.padding(padding),
                onAddItem = { isAddingItem = true },
            )
        } else {
            ReturnItemList(
                items = items,
                today = today,
                contentPadding = padding,
            )
        }
    }

    if (isAddingItem) {
        AddItemSheet(
            onDismiss = { isAddingItem = false },
            onAddItem = onAddItem,
        )
    }
}

@Composable
private fun EmptyState(
    modifier: Modifier = Modifier,
    onAddItem: () -> Unit,
) {
    Box(
        modifier = modifier.fillMaxSize().padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Inventory2,
                contentDescription = null,
                modifier = Modifier.size(54.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "아직 등록된 상품이 없습니다",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
            )
            Text(
                text = "구매한 상품을 추가하면 반품 기한을 놓치지 않도록 정리해 드릴게요.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Button(onClick = onAddItem) {
                Text("첫 상품 추가")
            }
        }
    }
}

@Composable
private fun ReturnItemList(
    items: List<ReturnItem>,
    today: LocalDate,
    contentPadding: PaddingValues,
) {
    val attentionItems = remember(items, today) {
        items.filter { ReturnDeadline.needsAttention(it.returnDeadline, it.status, today) }
    }
    val attentionIds = remember(attentionItems) { attentionItems.mapTo(mutableSetOf()) { it.id } }
    val recentItems = remember(items, attentionIds) {
        items.asSequence()
            .filterNot { it.id in attentionIds }
            .sortedByDescending(ReturnItem::createdAtMillis)
            .take(5)
            .toList()
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = 16.dp,
            top = contentPadding.calculateTopPadding() + 8.dp,
            end = 16.dp,
            bottom = contentPadding.calculateBottomPadding() + 24.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (attentionItems.isNotEmpty()) {
            item { SectionTitle("반품 마감 임박") }
            items(attentionItems, key = ReturnItem::id) { item ->
                ReturnItemCard(item = item, today = today)
            }
        }

        if (recentItems.isNotEmpty()) {
            item { SectionTitle("최근 등록", topSpacing = attentionItems.isNotEmpty()) }
            items(recentItems, key = ReturnItem::id) { item ->
                ReturnItemCard(item = item, today = today)
            }
        }
    }
}

@Composable
private fun SectionTitle(
    title: String,
    topSpacing: Boolean = false,
) {
    Text(
        text = title,
        modifier = Modifier.padding(
            top = if (topSpacing) 16.dp else 0.dp,
            bottom = 2.dp,
        ),
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
private fun ReturnItemCard(
    item: ReturnItem,
    today: LocalDate,
) {
    val daysRemaining = ReturnDeadline.daysRemaining(item.returnDeadline, today)
    val label = ReturnDeadline.label(item.returnDeadline, today)

    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(
                    text = item.productName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = item.storeName,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                HorizontalDivider(modifier = Modifier.padding(vertical = 2.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = CurrencyFormatter.won(item.priceWon),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Icon(
                        imageVector = item.status.icon,
                        contentDescription = null,
                        modifier = Modifier.size(15.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = item.status.title,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Spacer(modifier = Modifier.size(2.dp))
            Text(
                text = label,
                style = if (daysRemaining > 0) {
                    MaterialTheme.typography.titleMedium
                } else {
                    MaterialTheme.typography.labelLarge
                },
                fontWeight = FontWeight.SemiBold,
                color = deadlineColor(daysRemaining),
                textAlign = TextAlign.End,
            )
        }
    }
}

private val ReturnStatus.icon: ImageVector
    get() = when (this) {
        ReturnStatus.KEEPING -> Icons.Outlined.Inventory2
        ReturnStatus.RETURN_PLANNED -> Icons.Outlined.Undo
        ReturnStatus.RETURN_REQUESTED -> Icons.Outlined.Description
        ReturnStatus.SHIPPED -> Icons.Outlined.LocalShipping
        ReturnStatus.REFUND_PENDING -> Icons.Outlined.HourglassTop
        ReturnStatus.REFUNDED -> Icons.Outlined.CheckCircle
    }

@Composable
private fun deadlineColor(daysRemaining: Int): Color = when (daysRemaining) {
    in Int.MIN_VALUE..-1 -> MaterialTheme.colorScheme.onSurfaceVariant
    in 0..1 -> MaterialTheme.colorScheme.error
    in 2..3 -> Color(0xFFE66A00)
    else -> MaterialTheme.colorScheme.onSurface
}
