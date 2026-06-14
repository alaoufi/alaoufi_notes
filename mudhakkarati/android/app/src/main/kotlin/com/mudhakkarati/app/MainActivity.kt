package com.mudhakkarati.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// نرث من FlutterFragmentActivity لأن حزمة local_auth (البصمة) تتطلب ذلك.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.mudhakkarati.app/ringtone"
    private val dictationChannel = "com.mudhakkarati.app/dictation"
    private val pickRequest = 4201
    private val speechRequest = 4711
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSpeech: MethodChannel.Result? = null

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

        // قناة الإملاء الصوتيّ — تفتح نافذة التعرّف الأصلية في النظام.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dictationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(speechAvailable())
                    "recognize" -> startSpeech(call.argument<String>("locale"), result)
                    else -> result.notImplemented()
                }
            }
    }

    // (6) فحص توفّر الخدمة: محرّك تعرّف أو Activity يستقبل ACTION_RECOGNIZE_SPEECH.
    private fun speechAvailable(): Boolean {
        return try {
            val hasRecognizer = SpeechRecognizer.isRecognitionAvailable(this)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            val resolved = intent.resolveActivity(packageManager) != null
            hasRecognizer || resolved
        } catch (e: Exception) {
            false
        }
    }

    // (3,4) فتح نافذة الإملاء الأصلية بصيغة حرّة ولغة محدّدة.
    private fun startSpeech(locale: String?, result: MethodChannel.Result) {
        if (pendingSpeech != null) {
            result.error("busy", "الإملاء قيد التشغيل", null); return
        }
        val lang = if (locale.isNullOrEmpty()) "ar-SA" else locale
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "🎙️")
        }
        try {
            pendingSpeech = result
            startActivityForResult(intent, speechRequest)
        } catch (e: ActivityNotFoundException) {
            pendingSpeech = null
            result.error("unavailable", "لا توجد خدمة إملاء", null)
        } catch (e: Exception) {
            pendingSpeech = null
            result.error("error", e.message, null)
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
        when (requestCode) {
            pickRequest -> {
                val r = pendingResult ?: return
                pendingResult = null
                if (resultCode == Activity.RESULT_OK) {
                    val picked: Uri? =
                        data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                    r.success(picked?.toString())
                } else {
                    r.success(null)
                }
            }
            speechRequest -> {
                val r = pendingSpeech ?: return
                pendingSpeech = null
                // (5) اقرأ أول نتيجة غير فارغة من EXTRA_RESULTS.
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val results =
                        data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    val text = results?.firstOrNull { it.isNotBlank() } ?: ""
                    r.success(text)
                } else {
                    r.success(null) // أُلغيت العملية
                }
            }
        }
    }
}
