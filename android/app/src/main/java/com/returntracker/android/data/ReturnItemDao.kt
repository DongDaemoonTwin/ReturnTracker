package com.returntracker.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ReturnItemDao {
    @Query(
        """
        SELECT * FROM return_items
        ORDER BY returnDeadlineEpochDay ASC, createdAtMillis DESC
        """,
    )
    fun observeAll(): Flow<List<ReturnItem>>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(item: ReturnItem)
}
