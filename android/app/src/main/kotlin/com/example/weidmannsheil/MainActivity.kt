package com.example.weidmannsheil

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.weidmannsheil/audio"
    private var savedRingerVolume = 0
    private var savedNotificationVolume = 0
    private var savedRingerMode = AudioManager.RINGER_MODE_NORMAL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGhostMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    setGhostMode(enable)
                    result.success(true)
                }
                "getRingerMode" -> {
                    val status = getRingerMode()
                    result.success(status)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setGhostMode(enable: Boolean) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager == null) {
                android.util.Log.e("MainActivity", "AudioManager ist null!")
                return
            }

            if (enable) {
                // Ghost Mode ON: Speichere aktuelle Werte und schalte stumm
                savedRingerMode = audioManager.ringerMode
                savedRingerVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
                savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)

                android.util.Log.d("MainActivity", "Ghost Mode AN - Gespeicherte Werte: ringerMode=$savedRingerMode, ringVol=$savedRingerVolume, notifVol=$savedNotificationVolume")

                // Setze Ringer Mode auf Silent
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT

                // Setze Ringer und Notification Lautstärke auf 0
                audioManager.setStreamVolume(AudioManager.STREAM_RING, 0, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)

                android.util.Log.d("MainActivity", "Ghost Mode AN erfolgreich aktiviert")

                // WICHTIG: STREAM_MUSIC bleibt unberührt für Tierlaute!

            } else {
                // Ghost Mode OFF: Stelle ursprüngliche Werte wieder her
                android.util.Log.d("MainActivity", "Ghost Mode AUS - Stelle wieder her: ringerMode=$savedRingerMode, ringVol=$savedRingerVolume, notifVol=$savedNotificationVolume")

                audioManager.ringerMode = savedRingerMode

                // Stelle Lautstärken wieder her
                audioManager.setStreamVolume(AudioManager.STREAM_RING, savedRingerVolume, 0)
                audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)

                android.util.Log.d("MainActivity", "Ghost Mode AUS erfolgreich deaktiviert")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "FEHLER in setGhostMode: ${e.message}", e)
            e.printStackTrace()
        }
    }

    private fun getRingerMode(): String {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager == null) {
                android.util.Log.e("MainActivity", "AudioManager ist null in getRingerMode!")
                return "UNKNOWN"
            }

            val mode = when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_SILENT -> "SILENT"
                AudioManager.RINGER_MODE_VIBRATE -> "VIBRATE"
                AudioManager.RINGER_MODE_NORMAL -> "NORMAL"
                else -> "UNKNOWN"
            }

            android.util.Log.d("MainActivity", "getRingerMode: $mode")
            mode
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "FEHLER in getRingerMode: ${e.message}", e)
            "UNKNOWN"
        }
    }
}
