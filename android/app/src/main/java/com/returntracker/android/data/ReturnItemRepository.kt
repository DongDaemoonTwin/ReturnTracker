package com.returntracker.android.data

import kotlinx.coroutines.flow.Flow

class ReturnItemRepository(
    private val dao: ReturnItemDao,
) {
    val items: Flow<List<ReturnItem>> = dao.observeAll()

    suspend fun insert(item: ReturnItem) = dao.insert(item)
}
