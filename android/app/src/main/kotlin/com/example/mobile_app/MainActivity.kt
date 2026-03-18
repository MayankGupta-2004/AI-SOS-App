package com.example.mobile_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Binder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

// =============================================================================
// KavachService — ONE foreground service handling speech + recording
//
// CRITICAL RULES:
//   1. stopProtection() NEVER stops an active recording
//   2. Recording only stops after 10 min (native timer) or explicit stopRecording()
//   3. Speech and Recording are completely independent — one stopping does NOT stop the other
// =============================================================================

class KavachService : Service() {

    // ── Speech ────────────────────────────────────────────────────
    private var speechRecognizer: SpeechRecognizer? = null
    private var shouldListen = false
    var isListening = false
        private set

    // ── Recording ─────────────────────────────────────────────────
    private var mediaRecorder: MediaRecorder? = null
    var isRecording = false
        private set
    var currentRecordingPath: String? = null
        private set

    // ── System ────────────────────────────────────────────────────
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    // ── Callbacks to Flutter ──────────────────────────────────────
    var onKeywordDetected: ((String) -> Unit)? = null
    var onStatusUpdate: ((String) -> Unit)? = null

    // ── Auto-stop recording after 10 min ──────────────────────────
    private val autoStopRecordingRunnable = Runnable {
        Log.i(TAG, "10 min — auto-saving recording")
        stopRecording()
    }

    private val binder = LocalBinder()
    inner class LocalBinder : Binder() {
        fun getService(): KavachService = this@KavachService
    }
    override fun onBind(intent: Intent): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireWakeLock()
    }

    // ─────────────────────────────────────────────────────────────
    // START PROTECTION — starts speech listening only
    // ─────────────────────────────────────────────────────────────
    fun startProtection() {
        if (shouldListen) return
        shouldListen = true

        startForeground(NOTIF_PROTECTION, buildNotification(
            "Kavach Protection Active",
            "Listening for distress keywords..."
        ))

        Log.i(TAG, "Protection mode started")
        startKeywordListening()
    }

    // ─────────────────────────────────────────────────────────────
    // STOP PROTECTION — stops speech ONLY. NEVER touches recording.
    // ─────────────────────────────────────────────────────────────
    fun stopProtection() {
        shouldListen = false
        isListening  = false

        // Cancel only speech-related handlers, NOT the recording timer
        handler.removeCallbacksAndMessages(SPEECH_TOKEN)

        // Stop speech recognizer
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
        } catch (e: Exception) { /* ignore */ }
        speechRecognizer = null

        // ✅ CRITICAL: Do NOT stop recording here.
        // If recording is active, it continues independently.
        // It will stop on its own after 10 min via autoStopRecordingRunnable.

        if (!isRecording) {
            // Only remove foreground if not recording either
            stopForeground(STOP_FOREGROUND_REMOVE)
            releaseWakeLock()
        } else {
            // Keep foreground alive for the recording — just update notification
            updateNotification("Recording evidence in background...")
            Log.i(TAG, "Protection stopped — recording continues")
        }

        Log.i(TAG, "Speech stopped. isRecording=$isRecording")
        onStatusUpdate?.invoke("stopped")
    }

    // ─────────────────────────────────────────────────────────────
    // SPEECH — keyword listening loop
    // ─────────────────────────────────────────────────────────────
    private fun startKeywordListening() {
        if (!shouldListen || isRecording) return

        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) { /* ignore */ }

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e(TAG, "Speech recognition not available")
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {

            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                Log.i(TAG, "Listening for keywords...")
                onStatusUpdate?.invoke("listening")
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: run {
                    if (shouldListen) restartListeningAfter(200)
                    return
                }
                for (phrase in matches) {
                    val lower = phrase.lowercase().trim()
                    Log.i(TAG, "Heard: '$lower'")
                    if (isKeyword(lower)) {
                        Log.i(TAG, "KEYWORD: '$lower'")
                        triggerSOS(lower)
                        return
                    }
                }
                if (shouldListen) restartListeningAfter(200)
            }

            override fun onPartialResults(partial: Bundle?) {
                val text = partial
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.lowercase()?.trim() ?: return
                if (text.isBlank()) return
                Log.i(TAG, "Partial: '$text'")
                if (isKeyword(text)) {
                    Log.i(TAG, "KEYWORD (partial): '$text'")
                    triggerSOS(text)
                }
            }

            override fun onError(error: Int) {
                isListening = false
                val delay = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> 200L
                    SpeechRecognizer.ERROR_AUDIO          -> 800L
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> 1500L
                    else -> 500L
                }
                Log.w(TAG, "Speech error $error — restarting in ${delay}ms")
                if (shouldListen) restartListeningAfter(delay)
            }

            override fun onEndOfSpeech()                           { isListening = false }
            override fun onBeginningOfSpeech()                     {}
            override fun onRmsChanged(rmsdB: Float)                {}
            override fun onBufferReceived(buffer: ByteArray?)      {}
            override fun onEvent(eventType: Int, params: Bundle?)  {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "hi-IN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "hi-IN")
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, false)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 500L)
        }
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "startListening error: ${e.message}")
            if (shouldListen) restartListeningAfter(1000)
        }
    }

    // Use a token so we only cancel speech restarts, not recording timer
    private val SPEECH_TOKEN = Object()

    private fun restartListeningAfter(ms: Long) {
        handler.postDelayed({ startKeywordListening() }, ms)
    }

    // ─────────────────────────────────────────────────────────────
    // SOS TRIGGER — stops speech, starts recording independently
    // ─────────────────────────────────────────────────────────────
    private fun triggerSOS(keyword: String) {
        if (isRecording) {
            Log.w(TAG, "SOS already active — ignoring duplicate trigger")
            return
        }

        // Step 1: Stop speech ONLY (not recording)
        shouldListen = false
        isListening  = false
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
        } catch (e: Exception) { /* ignore */ }
        speechRecognizer = null

        Log.i(TAG, "=== SOS TRIGGERED: $keyword ===")

        // Step 2: Update notification
        updateNotification("SOS TRIGGERED — Recording started")
        showSOSNotification()

        // Step 3: Start recording INDEPENDENTLY
        // This runs on its own 10-min timer completely separate from speech
        startRecordingInternal()

        // Step 4: Notify Flutter for SMS + siren + UI (may be ignored if suspended)
        onKeywordDetected?.invoke(keyword)
    }

    // ─────────────────────────────────────────────────────────────
    // RECORDING — completely independent from speech
    // ─────────────────────────────────────────────────────────────
    private fun startRecordingInternal() {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return
        }

        val dir = getExternalFilesDir(null) ?: filesDir
        val recordingsDir = File(dir, "KavachRecordings")
        if (!recordingsDir.exists()) recordingsDir.mkdirs()

        val ts   = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
        val path = "${recordingsDir.absolutePath}/SOS_$ts.mp4"

        try {
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                MediaRecorder(this) else @Suppress("DEPRECATION") MediaRecorder()

            mediaRecorder!!.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setAudioChannels(1)
                setOutputFile(path)
                prepare()
                start()
            }

            currentRecordingPath = path
            isRecording          = true

            Log.i(TAG, "Recording STARTED: $path")

            // ✅ Schedule 10-min stop using postDelayed with NO token
            // so stopProtection() cannot accidentally cancel it
            handler.postDelayed(autoStopRecordingRunnable, 10 * 60 * 1000L)
            Log.i(TAG, "Auto-stop scheduled in 10 minutes")

        } catch (e: Exception) {
            Log.e(TAG, "Recording start error: ${e.message}")
            mediaRecorder?.release()
            mediaRecorder = null
        }
    }

    // Called by Flutter explicitly OR by 10-min timer
    fun stopRecording(): String? {
        if (!isRecording) return currentRecordingPath
        handler.removeCallbacks(autoStopRecordingRunnable)

        return try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording   = false

            // If protection mode is also off now, clean up foreground
            if (!shouldListen) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                releaseWakeLock()
            }

            Log.i(TAG, "Recording SAVED: $currentRecordingPath")
            currentRecordingPath
        } catch (e: Exception) {
            Log.e(TAG, "Recording stop error: ${e.message}")
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording   = false
            null
        }
    }

    // ─────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────
    private fun isKeyword(text: String): Boolean {
        val keywords = listOf(
            "help", "help me", "save me", "somebody help",
            "please help", "help help", "emergency", "danger", "sos",
            "bachao", "koi bachao", "bacchao", "mujhe bachao",
            "madad", "madad karo", "madad chahiye",
            "हेल्प", "हेल्प मी", "बचाओ", "कोई बचाओ",
            "मदद", "मदद करो", "मुझे बचाओ",
            "मुझे मदद चाहिए", "सहायता", "खतरा", "इमरजेंसी"
        )
        return keywords.any { text.contains(it) }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "Kavach::WakeLock"
        ).apply { acquire(12 * 60 * 60 * 1000L) }
    }

    private fun releaseWakeLock() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (e: Exception) { /* ignore */ }
        wakeLock = null
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_PROTECTION, buildNotification("Kavach", text))
    }

    private fun buildNotification(title: String, text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_PROTECTION)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun showSOSNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_SOS, NotificationCompat.Builder(this, CHANNEL_SOS)
            .setContentTitle("🚨 KAVACH SOS TRIGGERED")
            .setContentText("Recording started. SMS being sent to contacts.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(false)
            .build())
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(
                CHANNEL_PROTECTION, "Kavach Protection",
                NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel(
                CHANNEL_SOS, "Kavach SOS Alert",
                NotificationManager.IMPORTANCE_HIGH))
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "App removed — service continues")
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try { speechRecognizer?.destroy() } catch (e: Exception) { /* ignore */ }
        if (isRecording) {
            try { mediaRecorder?.stop(); mediaRecorder?.release() } catch (e: Exception) { /* ignore */ }
            mediaRecorder = null; isRecording = false
        }
        releaseWakeLock()
        super.onDestroy()
    }

    companion object {
        const val TAG                = "KavachService"
        const val CHANNEL_PROTECTION = "kavach_protection"
        const val CHANNEL_SOS        = "kavach_sos"
        const val NOTIF_PROTECTION   = 98
        const val NOTIF_SOS          = 97
    }
}

// =============================================================================
// MainActivity
// =============================================================================

class MainActivity : FlutterActivity() {

    private val SPEECH_CHANNEL = "com.example.mobile_app/speech"
    private val SIREN_CHANNEL  = "com.example.mobile_app/siren"
    private val RECORD_CHANNEL = "com.example.mobile_app/recorder"

    private var kavachService: KavachService? = null
    private var serviceBound  = false
    private var mediaPlayer: MediaPlayer? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            kavachService = (binder as KavachService.LocalBinder).getService()
            serviceBound  = true

            kavachService?.onKeywordDetected = { keyword ->
                runOnUiThread {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SPEECH_CHANNEL)
                            .invokeMethod("onKeywordDetected", keyword)
                    }
                }
            }
            kavachService?.onStatusUpdate = { status ->
                runOnUiThread {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SPEECH_CHANNEL)
                            .invokeMethod("onStatusUpdate", status)
                    }
                }
            }
            Log.i("MainActivity", "KavachService bound")
        }
        override fun onServiceDisconnected(name: ComponentName) {
            serviceBound = false; kavachService = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SPEECH CHANNEL ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> {
                        val intent = Intent(this, KavachService::class.java)
                        startForegroundService(intent)
                        if (!serviceBound) {
                            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
                        }
                        Handler(Looper.getMainLooper()).postDelayed({
                            kavachService?.startProtection()
                        }, 400)
                        result.success("started")
                    }
                    "stopListening" -> {
                        // ✅ Only stops speech — recording keeps running if active
                        kavachService?.stopProtection()
                        result.success("stopped")
                        // NOTE: We do NOT unbind or stopService here because
                        // recording may still be running inside KavachService
                    }
                    "isListening" -> result.success(kavachService?.isListening ?: false)
                    else -> result.notImplemented()
                }
            }

        // ── SIREN CHANNEL ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIREN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSiren" -> {
                        try {
                            releasePlayer()
                            val afd: AssetFileDescriptor =
                                assets.openFd("flutter_assets/assets/sounds/siren.mp3")
                            mediaPlayer = MediaPlayer().apply {
                                setAudioAttributes(AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build())
                                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                isLooping = true; prepare(); start()
                            }
                            afd.close()
                            result.success("started")
                        } catch (e: Exception) {
                            result.error("SIREN_ERROR", e.message, null)
                        }
                    }
                    "stopSiren" -> { releasePlayer(); result.success("stopped") }
                    else -> result.notImplemented()
                }
            }

        // ── RECORDER CHANNEL ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        // ✅ If already recording natively — just return path, don't restart
                        if (kavachService?.isRecording == true) {
                            Log.i("MainActivity", "Already recording natively — skipping Flutter start")
                            result.success(kavachService?.currentRecordingPath)
                            return@setMethodCallHandler
                        }
                        result.error("NO_RECORDING", "Recording not started by native service", null)
                    }
                    "stopRecording" -> result.success(kavachService?.stopRecording())
                    "isRecording"   -> result.success(kavachService?.isRecording ?: false)
                    "currentPath"   -> result.success(kavachService?.currentRecordingPath)
                    else -> result.notImplemented()
                }
            }
    }

    private fun releasePlayer() {
        mediaPlayer?.let {
            try { if (it.isPlaying) it.stop(); it.release() } catch (e: Exception) { /* ignore */ }
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        releasePlayer()
        if (serviceBound) {
            try { unbindService(serviceConnection) } catch (e: Exception) { /* ignore */ }
            serviceBound = false
        }
        super.onDestroy()
    }
}