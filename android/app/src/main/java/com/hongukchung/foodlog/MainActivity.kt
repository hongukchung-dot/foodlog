package com.hongukchung.foodlog

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.content.IntentCompat
import androidx.lifecycle.lifecycleScope
import com.hongukchung.foodlog.ui.FoodLogNavHost
import com.hongukchung.foodlog.ui.theme.FoodLogTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // 다른 앱(갤러리, 메신저 등)에서 "공유 → 푸드로그"로 보낸 사진을
        // 앱 저장소로 복사해 미분석 사진함에 넣는다 (takenAt은 EXIF에서).
        val sharedUris = extractSharedImages(intent)
        val startInInbox = sharedUris.isNotEmpty()
        if (startInInbox) {
            val appContainer = application as FoodLogApp
            lifecycleScope.launch {
                for (uri in sharedUris) {
                    appContainer.photoStore.importFromUri(uri)?.let { photo ->
                        appContainer.database.photoDao().insert(photo)
                    }
                }
            }
        }

        setContent {
            FoodLogTheme {
                FoodLogNavHost(startInInbox = startInInbox)
            }
        }
    }

    private fun extractSharedImages(intent: Intent?): List<Uri> {
        intent ?: return emptyList()
        val isImage = intent.type?.startsWith("image/") == true
        return when {
            intent.action == Intent.ACTION_SEND && isImage ->
                listOfNotNull(
                    IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java),
                )

            intent.action == Intent.ACTION_SEND_MULTIPLE && isImage ->
                IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                    ?.filterNotNull()
                    .orEmpty()

            else -> emptyList()
        }
    }
}
