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
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (enable) {
            // Ghost Mode ON: Speichere aktuelle Werte und schalte stumm
            savedRingerMode = audioManager.ringerMode
            savedRingerVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)

            // Setze Ringer Mode auf Silent
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT

            // Setze Ringer und Notification Lautstärke auf 0
            audioManager.setStreamVolume(AudioManager.STREAM_RING, 0, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)

            // WICHTIG: STREAM_MUSIC bleibt unberührt für Tierlaute!

        } else {
            // Ghost Mode OFF: Stelle ursprüngliche Werte wieder her
            audioManager.ringerMode = savedRingerMode

            // Stelle Lautstärken wieder her
            audioManager.setStreamVolume(AudioManager.STREAM_RING, savedRingerVolume, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)
        }
    }

    private fun getRingerMode(): String {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return when (audioManager.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "SILENT"
            AudioManager.RINGER_MODE_VIBRATE -> "VIBRATE"
            AudioManager.RINGER_MODE_NORMAL -> "NORMAL"
            else -> "UNKNOWN"
        }
    }
}
