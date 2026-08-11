package com.returntracker.android

import android.os.Bundle
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.ViewModelProvider
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import com.returntracker.android.ui.HomeScreen
import com.returntracker.android.ui.ReturnTrackerViewModel
import com.returntracker.android.ui.theme.ReturnTrackerTheme

class MainActivity : ComponentActivity() {
    private lateinit var trackerViewModel: ReturnTrackerViewModel

    private val authorizationLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult(),
    ) { activityResult ->
        try {
            val result = Identity.getAuthorizationClient(this)
                .getAuthorizationResultFromIntent(activityResult.data)
            continueGmailSync(result)
        } catch (error: ApiException) {
            trackerViewModel.gmailAuthorizationFailed(error)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val repository = (application as ReturnTrackerApplication).repository
        trackerViewModel = ViewModelProvider(
            this,
            ReturnTrackerViewModel.factory(repository),
        )[ReturnTrackerViewModel::class.java]

        setContent {
            ReturnTrackerTheme {
                val items by trackerViewModel.items.collectAsStateWithLifecycle(initialValue = emptyList())
                val gmailSyncState by trackerViewModel.gmailSyncState.collectAsStateWithLifecycle()

                HomeScreen(
                    items = items,
                    gmailSyncState = gmailSyncState,
                    onAddItem = trackerViewModel::addItem,
                    onSyncGmail = ::requestGmailSync,
                    onDismissSyncMessage = trackerViewModel::dismissGmailSyncMessage,
                )
            }
        }
    }

    private fun requestGmailSync() {
        trackerViewModel.beginGmailAuthorization()
        val request = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(GMAIL_READONLY_SCOPE)))
            .build()

        Identity.getAuthorizationClient(this)
            .authorize(request)
            .addOnSuccessListener { result ->
                val pendingIntent = result.pendingIntent
                if (result.hasResolution() && pendingIntent != null) {
                    authorizationLauncher.launch(
                        IntentSenderRequest.Builder(pendingIntent.intentSender).build(),
                    )
                } else {
                    continueGmailSync(result)
                }
            }
            .addOnFailureListener { error -> trackerViewModel.gmailAuthorizationFailed(error) }
    }

    private fun continueGmailSync(result: AuthorizationResult) {
        val accessToken = result.accessToken
        if (accessToken.isNullOrBlank()) {
            trackerViewModel.gmailAuthorizationFailed(
                IllegalStateException("Gmail 읽기 권한이 승인되지 않았습니다."),
            )
            return
        }
        trackerViewModel.syncGmail(accessToken)
    }

    private companion object {
        const val GMAIL_READONLY_SCOPE = "https://www.googleapis.com/auth/gmail.readonly"
    }
}
