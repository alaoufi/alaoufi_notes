package com.mudhakkarati.app

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// نرث من FlutterFragmentActivity لأن حزمة local_auth (البصمة) تتطلب ذلك.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.mudhakkarati.app/ringtone"
    private val pickRequest = 4201
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickRingtone" -> openPicker(call.argument<String>("current"), result)
                    "ringtoneTitle" -> result.success(titleFor(call.argument<String>("uri")))
                    else -> result.notImplemented()
                }
            }
    }

    private fun openPicker(current: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "اختيار قيد التنفيذ", null); return
        }
        pendingResult = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE,
                RingtoneManager.TYPE_NOTIFICATION or RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "اختر نغمة التنبيه")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            if (!current.isNullOrEmpty()) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
            }
        }
        try {
            startActivityForResult(intent, pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.error("unavailable", "تعذّر فتح منتقي النغمات", e.message)
        }
    }

    private fun titleFor(uri: String?): String? {
        if (uri.isNullOrEmpty()) return null
        return try {
            RingtoneManager.getRingtone(this, Uri.parse(uri))?.getTitle(this)
        } catch (e: Exception) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val r = pendingResult ?: return
        pendingResult = null
        if (resultCode == Activity.RESULT_OK) {
            val picked: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            r.success(picked?.toString())
        } else {
            r.success(null) // أُلغي الاختيار
        }
    }
}
