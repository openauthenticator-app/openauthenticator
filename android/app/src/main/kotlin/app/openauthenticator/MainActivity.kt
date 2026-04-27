package app.openauthenticator

import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.browser.auth.AuthTabIntent
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingAuthSession = false

    private val authTabLauncher: ActivityResultLauncher<Intent> =
        AuthTabIntent.registerActivityResultLauncher(this) { result ->
            pendingAuthSession = false
            when (result.resultCode) {
                AuthTabIntent.RESULT_OK -> {
                    val resultUri = result.resultUri
                    if (resultUri != null) dispatchAppLink(resultUri)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.openauthenticator.webauth").setMethodCallHandler { call, result ->
            when (call.method) {
                "authenticate" -> authenticate(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun authenticate(call: MethodCall, result: MethodChannel.Result) {
        if (pendingAuthSession) {
            result.error("already_running", "A web authentication session is already running.", null)
            return
        }
        val url = call.argument<String>("url")
        val callbackUrlScheme = call.argument<String>("callbackUrlScheme")
        if (url.isNullOrBlank() || callbackUrlScheme.isNullOrBlank()) {
            result.error("invalid_arguments", "Expected non-empty url and callbackUrlScheme arguments.", null)
            return
        }
        val uri = Uri.parse(url)
        pendingAuthSession = true
        try {
            AuthTabIntent.Builder()
                .build()
                .launch(authTabLauncher, uri, callbackUrlScheme)
            result.success(null)
        } catch (ex: Exception) {
            try {
                pendingAuthSession = false
                CustomTabsIntent.Builder()
                    .build()
                    .launchUrl(this, uri)
                result.success(null)
            } catch (fallbackEx: Exception) {
                result.error("launch_failed", fallbackEx.localizedMessage ?: ex.localizedMessage, null)
            }
        }
    }

    private fun dispatchAppLink(uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW, uri)
        intent.addCategory(Intent.CATEGORY_BROWSABLE)
        intent.addCategory(Intent.CATEGORY_DEFAULT)
        super.onNewIntent(intent)
    }
}
