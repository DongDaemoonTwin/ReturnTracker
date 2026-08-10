package com.returntracker.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [ReturnItem::class],
    version = 1,
    exportSchema = false,
)
abstract class ReturnTrackerDatabase : RoomDatabase() {
    abstract fun returnItemDao(): ReturnItemDao

    companion object {
        @Volatile
        private var instance: ReturnTrackerDatabase? = null

        fun getInstance(context: Context): ReturnTrackerDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    ReturnTrackerDatabase::class.java,
                    "return-tracker.db",
                ).build().also { instance = it }
            }
    }
}
