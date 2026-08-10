package com.returntracker.android

import android.app.Application
import com.returntracker.android.data.ReturnItemRepository
import com.returntracker.android.data.ReturnTrackerDatabase

class ReturnTrackerApplication : Application() {
    val repository: ReturnItemRepository by lazy {
        ReturnItemRepository(ReturnTrackerDatabase.getInstance(this).returnItemDao())
    }
}
