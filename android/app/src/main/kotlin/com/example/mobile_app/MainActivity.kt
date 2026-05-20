package com.example.mobile_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
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
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

// =============================================================================
// KavachBootReceiver — starts service on boot / package update
// =============================================================================

class KavachBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED       ||
            action == "android.intent.action.LOCKED_BOOT_COMPLETED" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.i("KavachBoot", "Boot/update received — restarting KavachService")
            startKavachService(context)
        }
    }
}

// =============================================================================
// KavachRestartReceiver
//
// THE KEY FIX — WHY THIS EXISTS:
//
// SpeechRecognizer is bound to the app's main process. When the user swipes
// the app away, the process is killed and the recognizer dies with it — even
// though KavachService (START_STICKY) survives.
//
// We CANNOT reliably restart the mic from onTaskRemoved() via a Handler post
// because the Looper may be torn down before the runnable fires.
//
// Instead, onTaskRemoved() sends a broadcast. This receiver catches it and
// calls startForegroundService() with EXTRA_RESTART_SPEECH=true. By the time
// the broadcast is delivered the process has fully stabilised, so
// onStartCommand() can safely create a new SpeechRecognizer and start the mic.
// =============================================================================

class KavachRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_RESTART_SPEECH) {
            Log.i("KavachRestart", "Restart broadcast received — restarting mic")
            val svc = Intent(context, KavachService::class.java)
                .putExtra(EXTRA_RESTART_SPEECH, true)
            startKavachService(context, svc)
        }
    }

    companion object {
        const val ACTION_RESTART_SPEECH = "com.example.mobile_app.RESTART_SPEECH"
        const val EXTRA_RESTART_SPEECH  = "restart_speech"
    }
}

// =============================================================================
// Helper — safe service start used by both receivers + MainActivity
// =============================================================================

private fun startKavachService(context: Context, intent: Intent? = null) {
    val svc = intent ?: Intent(context, KavachService::class.java)

    // Android 14+ (API 34) requires RECORD_AUDIO to be granted before you can
    // start a foreground service with type=microphone. Without this check the
    // app crashes with SecurityException on Samsung One UI 6+ / Pixel 8+.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34
        val micGranted = ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!micGranted) {
            Log.w("KavachService", "RECORD_AUDIO not granted — deferring service start")
            return
        }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(svc)
    } else {
        context.startService(svc)
    }
}

// =============================================================================
// KavachService
// =============================================================================

class KavachService : Service() {

    private var speechRecognizer: SpeechRecognizer? = null

    // shouldListen        = speech loop is currently running
    // userWantsProtection = user explicitly enabled protection (survives kills)
    private var shouldListen        = false
    private var userWantsProtection = false

    var isListening = false
        private set

    private var mediaRecorder: MediaRecorder? = null
    var isRecording = false
        private set
    var currentRecordingPath: String? = null
        private set

    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    // Separate tokens so cancel() calls are surgical
    private val SPEECH_TOKEN  = Object()
    private val RESTART_TOKEN = Object()

    var onKeywordDetected: ((String) -> Unit)? = null
    var onStatusUpdate:    ((String) -> Unit)? = null

    // When false → service handles SOS natively (Flutter not available)
    var flutterEngineAlive = false

    private val autoStopRecordingRunnable = Runnable {
        Log.i(TAG, "10 min — auto-saving recording")
        stopRecording()
    }

    private val binder = LocalBinder()
    inner class LocalBinder : Binder() {
        fun getService(): KavachService = this@KavachService
    }
    override fun onBind(intent: Intent): IBinder = binder

    // ─────────────────────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireWakeLock()

        val notification = buildNotification("Kavach", "Protection ready — tap to activate")

        // FIX: Android 14+ (targetSDK=36) requires the serviceType argument in
        // startForeground() when the service declares a foregroundServiceType.
        // Without it → SecurityException on Samsung One UI 6, Pixel 8, etc.
        // The 3-arg overload exists from API 29 (Android 10) onward.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // API 29
            startForeground(
                NOTIF_PROTECTION,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIF_PROTECTION, notification)
        }

        Log.i(TAG, "KavachService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val restartSpeech = intent?.getBooleanExtra(
            KavachRestartReceiver.EXTRA_RESTART_SPEECH, false) ?: false

        // Broadcast-triggered restart after app was killed
        if (restartSpeech && userWantsProtection && !isRecording) {
            Log.i(TAG, "onStartCommand: restart_speech=true — restarting mic")
            shouldListen = false // reset so startKeywordListening() doesn't bail early
            handler.postDelayed({
                if (userWantsProtection && !shouldListen && !isRecording) {
                    shouldListen = true
                    updateNotification("👂 Listening continues (background)...")
                    startKeywordListening()
                }
            }, 800)
        }

        // Re-issue startForeground on every onStartCommand call (required on
        // some OEM ROM versions that reset the FGS state on service restart)
        val notification = buildNotification(
            "Kavach",
            when {
                isRecording         -> "🎙️ Recording evidence..."
                userWantsProtection -> "👂 Listening for distress keywords..."
                else                -> "Protection ready — tap to activate"
            }
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_PROTECTION,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIF_PROTECTION, notification)
        }

        Log.i(TAG, "onStartCommand — shouldListen=$shouldListen isRecording=$isRecording")
        return START_STICKY
    }

    // ─────────────────────────────────────────────────────────────
    // PUBLIC PROTECTION API
    // ─────────────────────────────────────────────────────────────

    /** User tapped "Start Protection" in the Flutter UI */
    fun startProtection() {
        userWantsProtection = true
        if (shouldListen) return
        shouldListen = true
        updateNotification("👂 Listening for distress keywords...")
        Log.i(TAG, "Protection started — userWantsProtection=true")
        startKeywordListening()
    }

    /**
     * User explicitly tapped "Stop Protection".
     * Clears userWantsProtection so native listening does NOT auto-restart.
     */
    fun explicitStopProtection() {
        userWantsProtection = false
        _stopSpeechEngine()
        if (!isRecording) updateNotification("Protection OFF")
        else              updateNotification("🎙️ Recording evidence in background...")
        Log.i(TAG, "Protection explicitly stopped — isRecording=$isRecording")
        onStatusUpdate?.invoke("stopped")
    }

    /**
     * Flutter going to background (MainActivity.onStop).
     * Does NOT clear userWantsProtection.
     * Stops Flutter-driven STT and schedules native restart.
     */
    fun pauseForBackground() {
        if (!userWantsProtection) return
        Log.i(TAG, "Flutter pausing — native mic will take over")
        _stopSpeechEngine()
        handler.removeCallbacksAndMessages(RESTART_TOKEN)
        handler.postDelayed(Runnable {
            if (userWantsProtection && !shouldListen && !isRecording) {
                Log.i(TAG, "Native restart after Flutter pause")
                shouldListen = true
                updateNotification("👂 Listening continues (background)...")
                startKeywordListening()
            }
        }, RESTART_TOKEN, 1200L)
    }

    /** Legacy alias kept so Flutter "stopListening" channel call works */
    fun stopProtection() = explicitStopProtection()

    // ─────────────────────────────────────────────────────────────
    // INTERNAL — stop speech engine cleanly
    // ─────────────────────────────────────────────────────────────

    private fun _stopSpeechEngine() {
        shouldListen = false
        isListening  = false
        handler.removeCallbacksAndMessages(SPEECH_TOKEN)
        handler.removeCallbacksAndMessages(RESTART_TOKEN)
        try { speechRecognizer?.stopListening() } catch (_: Exception) {}
        try { speechRecognizer?.cancel()        } catch (_: Exception) {}
        try { speechRecognizer?.destroy()       } catch (_: Exception) {}
        speechRecognizer = null
    }

    // ─────────────────────────────────────────────────────────────
    // NATIVE SPEECH RECOGNITION
    // Keeps running while shouldListen=true — screen locked, no UI.
    // ─────────────────────────────────────────────────────────────

    private fun startKeywordListening() {
        if (!shouldListen || isRecording) return

        // Guard: RECORD_AUDIO must be granted — if the user revoked it after
        // starting protection, bail out cleanly instead of crashing.
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO not granted — cannot start speech recognition")
            _stopSpeechEngine()
            return
        }

        // Always destroy the old instance first — avoids ERROR_RECOGNIZER_BUSY
        try { speechRecognizer?.cancel(); speechRecognizer?.destroy() } catch (_: Exception) {}
        speechRecognizer = null

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e(TAG, "SpeechRecognizer not available on this device")
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {

            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                onStatusUpdate?.invoke("listening")
                Log.i(TAG, "👂 Mic ON")
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                val matches = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?: run { if (shouldListen) restartListeningAfter(200); return }
                for (phrase in matches) {
                    val lower = phrase.lowercase().trim()
                    Log.i(TAG, "Heard: '$lower'")
                    if (isKeyword(lower)) {
                        Log.i(TAG, "🚨 KEYWORD: '$lower'")
                        handleKeywordDetected(lower)
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
                if (isKeyword(text)) {
                    Log.i(TAG, "🚨 KEYWORD (partial): '$text'")
                    handleKeywordDetected(text)
                }
            }

            override fun onError(error: Int) {
                isListening = false
                val delay = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> 400L
                    SpeechRecognizer.ERROR_AUDIO           -> 1000L
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> 2000L
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                        Log.e(TAG, "RECORD_AUDIO permission missing!"); 5000L
                    }
                    else -> 800L
                }
                Log.w(TAG, "Speech error $error — retry in ${delay}ms")
                if (shouldListen) restartListeningAfter(delay)
            }

            override fun onEndOfSpeech()                          { isListening = false }
            override fun onBeginningOfSpeech()                    {}
            override fun onRmsChanged(rmsdB: Float)               {}
            override fun onBufferReceived(buffer: ByteArray?)     {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE,            "hi-IN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "hi-IN")
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, false)
            putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES",
                arrayOf("en-IN", "mr-IN", "gu-IN", "pa-IN", "bn-IN",
                        "ta-IN", "te-IN", "kn-IN", "ml-IN"))
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,          2500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,                    300L)
        }
        try {
            speechRecognizer?.startListening(intent)
            Log.i(TAG, "SpeechRecognizer.startListening() — OK")
        } catch (e: Exception) {
            Log.e(TAG, "startListening error: ${e.message}")
            if (shouldListen) restartListeningAfter(1500)
        }
    }

    private fun restartListeningAfter(ms: Long) {
        handler.postDelayed(Runnable { startKeywordListening() }, SPEECH_TOKEN, ms)
    }

    // ─────────────────────────────────────────────────────────────
    // KEYWORD HANDLING — with or without Flutter
    // ─────────────────────────────────────────────────────────────

    private fun handleKeywordDetected(keyword: String) {
        if (flutterEngineAlive && onKeywordDetected != null) {
            Log.i(TAG, "Keyword → Flutter (engine alive)")
            onKeywordDetected?.invoke(keyword)
        } else {
            Log.i(TAG, "Keyword → Native SOS (Flutter dead)")
            triggerSOSNatively(keyword)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // NATIVE SOS — no Flutter UI available (screen locked / killed)
    // No countdown: user can't see or tap anything.
    // ─────────────────────────────────────────────────────────────

    private fun triggerSOSNatively(keyword: String) {
        if (isRecording) { Log.w(TAG, "Native SOS — already recording"); return }
        Log.i(TAG, "=== NATIVE SOS: $keyword ===")
        _stopSpeechEngine()
        showSOSNotification()
        updateNotification("🚨 SOS! Recording evidence...")
        startRecordingInternal()
        Log.i(TAG, "Native SOS complete — recording started")
    }

    // ─────────────────────────────────────────────────────────────
    // RECORDING
    // ─────────────────────────────────────────────────────────────

    fun startRecordingFromFlutter(): String? {
        if (isRecording) {
            Log.i(TAG, "Already recording: $currentRecordingPath")
            return currentRecordingPath
        }
        startRecordingInternal()
        return currentRecordingPath
    }

    private fun startRecordingInternal() {
        if (isRecording) return
        val dir           = getExternalFilesDir(null) ?: filesDir
        val recordingsDir = File(dir, "KavachRecordings").also { it.mkdirs() }
        val ts            = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
        val path          = "${recordingsDir.absolutePath}/SOS_$ts.mp4"

        try {
            mediaRecorder = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                MediaRecorder(this) else @Suppress("DEPRECATION") MediaRecorder()).apply {
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
            isRecording = true
            Log.i(TAG, "✅ Recording STARTED: $path")
            handler.postDelayed(autoStopRecordingRunnable, 10 * 60 * 1000L)
            renewWakeLock()
        } catch (e: Exception) {
            Log.e(TAG, "Recording start error: ${e.message}")
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
        }
    }

    fun stopRecording(): String? {
        if (!isRecording) return currentRecordingPath
        handler.removeCallbacks(autoStopRecordingRunnable)
        return try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
            if (!shouldListen) updateNotification("Recording saved.")
            Log.i(TAG, "✅ Recording SAVED: $currentRecordingPath")
            currentRecordingPath
        } catch (e: Exception) {
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
            null
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WAKELOCK
    // ─────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Kavach::WakeLock")
            .apply { acquire(15 * 60 * 1000L) }
    }

    private fun renewWakeLock() {
        releaseWakeLock()
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Kavach::WakeLock")
            .apply { acquire(15 * 60 * 1000L) }
        Log.i(TAG, "WakeLock renewed 15 min")
    }

    private fun releaseWakeLock() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        wakeLock = null
    }

    // ─────────────────────────────────────────────────────────────
    // KEYWORDS
    // ─────────────────────────────────────────────────────────────

    private fun isKeyword(text: String): Boolean {
        val keywords = listOf(
            "help", "help me", "save me", "somebody help", "please help",
            "help help", "emergency", "danger", "sos", "call police",
            "bachao", "koi bachao", "bacchao", "mujhe bachao",
            "madad", "madad karo", "madad chahiye",
            "बचाओ", "कोई बचाओ", "मुझे बचाओ", "मदद", "मदद करो",
            "मुझे मदद चाहिए", "सहायता", "खतरा", "इमरजेंसी", "हेल्प",
            "உதவி", "உதவுங்கள்", "udavi", "udavungal",
            "సహాయం", "sahayam",
            "সাহায্য", "বাঁচাও", "shahajjo",
            "मदत", "वाचवा", "madat",
            "મદદ", "bachavo",
            "ಸಹಾಯ", "sahaya",
            "സഹായം", "sahaayam",
            "ਮਦਦ", "ਬਚਾਓ", "khatra"
        )
        return keywords.any { text.contains(it) }
    }

    // ─────────────────────────────────────────────────────────────
    // NOTIFICATIONS
    // ─────────────────────────────────────────────────────────────

    fun updateNotification(text: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_PROTECTION, buildNotification("Kavach", text))
    }

    private fun buildNotification(title: String, text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_PROTECTION)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun showSOSNotification() {
        val openApp = PendingIntent.getActivity(
            this, 1,
            Intent(this, MainActivity::class.java)
                .apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_SOS, NotificationCompat.Builder(this, CHANNEL_SOS)
            .setContentTitle("🚨 KAVACH SOS TRIGGERED")
            .setContentText("Keyword detected! Recording started. Tap to open.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openApp)
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

    // ─────────────────────────────────────────────────────────────
    // SERVICE SURVIVAL AFTER APP SWIPE
    // ─────────────────────────────────────────────────────────────

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "App swiped away — service survives, scheduling mic restart via broadcast")
        flutterEngineAlive = false

        updateNotification(
            when {
                isRecording         -> "🎙️ Recording continues (app removed)"
                userWantsProtection -> "👂 Listening continues (app removed)"
                else                -> "Kavach active in background"
            }
        )

        if (userWantsProtection && !isRecording) {
            val broadcast = Intent(KavachRestartReceiver.ACTION_RESTART_SPEECH)
                .setPackage(packageName)
            sendBroadcast(broadcast)
            Log.i(TAG, "Restart broadcast sent — mic will restart shortly")
        }

        // Do NOT call stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        Log.i(TAG, "Service destroyed — START_STICKY will restart it")
        handler.removeCallbacksAndMessages(null)
        try { speechRecognizer?.destroy() } catch (_: Exception) {}
        if (isRecording) {
            try { mediaRecorder?.stop(); mediaRecorder?.release() } catch (_: Exception) {}
            mediaRecorder = null
            isRecording = false
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
    private val SMS_CHANNEL    = "com.example.mobile_app/sms"

    private var kavachService: KavachService? = null
    private var serviceBound = false
    private var mediaPlayer: MediaPlayer? = null
    private var pendingRecordingResult: MethodChannel.Result? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            kavachService = (binder as KavachService.LocalBinder).getService()
            serviceBound  = true
            kavachService?.flutterEngineAlive = true
            Log.i("MainActivity", "KavachService bound — Flutter alive")

            pendingRecordingResult?.let { result ->
                pendingRecordingResult = null
                result.success(kavachService?.startRecordingFromFlutter())
            }

            kavachService?.onKeywordDetected = { keyword ->
                runOnUiThread {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
                        MethodChannel(m, SPEECH_CHANNEL).invokeMethod("onKeywordDetected", keyword)
                    }
                }
            }
            kavachService?.onStatusUpdate = { status ->
                runOnUiThread {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
                        MethodChannel(m, SPEECH_CHANNEL).invokeMethod("onStatusUpdate", status)
                    }
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            serviceBound = false
            kavachService = null
        }
    }

    override fun onStart() {
        super.onStart()
        ensureServiceBound()
    }

    override fun onStop() {
        // App going to background — Flutter STT pauses, native takes over
        kavachService?.flutterEngineAlive = false
        kavachService?.pauseForBackground()
        super.onStop()
    }

    override fun onRestart() {
        super.onRestart()
        // App back in foreground — Flutter is alive again
        kavachService?.flutterEngineAlive = true
        Log.i("MainActivity", "App resumed — Flutter alive")
    }

    private fun ensureServiceBound() {
        val intent = Intent(this, KavachService::class.java)

        // FIX: use the shared helper which guards against missing RECORD_AUDIO
        // on Android 14+ before calling startForegroundService().
        startKavachService(this, intent)

        if (!serviceBound) {
            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        } else {
            kavachService?.flutterEngineAlive = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SPEECH CHANNEL ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> {
                        if (serviceBound) {
                            kavachService?.startProtection()
                        } else {
                            ensureServiceBound()
                            Handler(Looper.getMainLooper()).postDelayed({
                                kavachService?.startProtection()
                            }, 700)
                        }
                        result.success("started")
                    }
                    "stopListening" -> {
                        // User explicitly stopping — clears userWantsProtection
                        kavachService?.explicitStopProtection()
                        result.success("stopped")
                    }
                    "isListening" -> result.success(kavachService?.isListening ?: false)
                    else          -> result.notImplemented()
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
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_ALARM)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                        .build()
                                )
                                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                isLooping = true
                                prepare()
                                start()
                            }
                            afd.close()
                            result.success("started")
                        } catch (e: Exception) {
                            result.error("SIREN_ERROR", e.message, null)
                        }
                    }
                    "stopSiren" -> { releasePlayer(); result.success("stopped") }
                    else        -> result.notImplemented()
                }
            }

        // ── RECORDER CHANNEL ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        if (serviceBound && kavachService != null) {
                            result.success(kavachService?.startRecordingFromFlutter())
                        } else {
                            pendingRecordingResult = result
                            ensureServiceBound()
                        }
                    }
                    "stopRecording" -> result.success(kavachService?.stopRecording())
                    "isRecording"   -> result.success(kavachService?.isRecording ?: false)
                    "currentPath"   -> result.success(kavachService?.currentRecordingPath)
                    else            -> result.notImplemented()
                }
            }

        // ── SMS CHANNEL ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSMS" -> {
                        val phone = call.argument<String>("phone") ?: run {
                            result.error("INVALID", "phone required", null)
                            return@setMethodCallHandler
                        }
                        val message = call.argument<String>("message") ?: run {
                            result.error("INVALID", "message required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                                getSystemService(SmsManager::class.java)
                            else @Suppress("DEPRECATION") SmsManager.getDefault()

                            val parts = smsManager.divideMessage(message)
                            if (parts.size == 1)
                                smsManager.sendTextMessage(phone, null, message, null, null)
                            else
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)

                            Log.i("MainActivity", "✅ SMS → $phone")
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ SMS failed: ${e.message}")
                            result.error("SMS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun releasePlayer() {
        mediaPlayer?.let {
            try { if (it.isPlaying) it.stop(); it.release() } catch (_: Exception) {}
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        kavachService?.flutterEngineAlive = false
        releasePlayer()
        if (serviceBound) {
            try { unbindService(serviceConnection) } catch (_: Exception) {}
            serviceBound = false
        }
        super.onDestroy()
    }
}