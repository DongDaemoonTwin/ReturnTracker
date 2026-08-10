package com.returntracker.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.returntracker.android.ui.HomeScreen
import com.returntracker.android.ui.ReturnTrackerViewModel
import com.returntracker.android.ui.theme.ReturnTrackerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val repository = (application as ReturnTrackerApplication).repository

        setContent {
            ReturnTrackerTheme {
                val viewModel: ReturnTrackerViewModel = viewModel(
                    factory = ReturnTrackerViewModel.factory(repository),
                )
                val items by viewModel.items.collectAsStateWithLifecycle(initialValue = emptyList())

                HomeScreen(
                    items = items,
                    onAddItem = viewModel::addItem,
                )
            }
        }
    }
}
