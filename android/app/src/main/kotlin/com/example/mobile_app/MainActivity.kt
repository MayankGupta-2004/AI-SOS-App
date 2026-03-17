package com.example.mobile_app

import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.mobile_app/siren"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "startSiren" -> {
                        try {
                            // Stop any existing instance first
                            releasePlayer()

                            // Open siren.mp3 from Flutter assets
                            val afd: AssetFileDescriptor =
                                assets.openFd("flutter_assets/assets/sounds/siren.mp3")

                            mediaPlayer = MediaPlayer().apply {
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_ALARM)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                        .build()
                                )
                                setDataSource(
                                    afd.fileDescriptor,
                                    afd.startOffset,
                                    afd.length
                                )
                                isLooping = true
                                prepare()
                                start()
                            }
                            afd.close()

                            android.util.Log.i("Siren", "✅ Siren started via native MediaPlayer")
                            result.success("started")

                        } catch (e: Exception) {
                            android.util.Log.e("Siren", "❌ startSiren error: ${e.message}")
                            result.error("SIREN_ERROR", e.message, null)
                        }
                    }

                    "stopSiren" -> {
                        try {
                            releasePlayer()
                            android.util.Log.i("Siren", "🔇 Siren stopped")
                            result.success("stopped")
                        } catch (e: Exception) {
                            android.util.Log.e("Siren", "❌ stopSiren error: ${e.message}")
                            result.error("SIREN_STOP_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun releasePlayer() {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (_: Exception) {}
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}