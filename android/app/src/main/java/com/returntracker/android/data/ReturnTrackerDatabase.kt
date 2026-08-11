package com.returntracker.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [ReturnItem::class],
    version = 2,
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
                )
                    .addMigrations(MIGRATION_1_2)
                    .build()
                    .also { instance = it }
            }

        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE return_items ADD COLUMN sourceRawValue TEXT NOT NULL DEFAULT 'MANUAL'")
                db.execSQL("ALTER TABLE return_items ADD COLUMN sourceMessageId TEXT")
                db.execSQL("ALTER TABLE return_items ADD COLUMN needsReview INTEGER NOT NULL DEFAULT 0")
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS index_return_items_sourceMessageId " +
                        "ON return_items(sourceMessageId)",
                )
            }
        }
    }
}
