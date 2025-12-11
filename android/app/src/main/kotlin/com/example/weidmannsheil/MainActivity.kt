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
    private var savedMusicVolume = 0

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
            // Ghost Mode ON: Anrufe und Benachrichtigungen stumm, aber Musik/Tierlaute aktiv

            // 1. Speichere aktuelle Werte
            savedRingerMode = audioManager.ringerMode
            savedRingerVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            savedNotificationVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            savedMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

            // 2. Setze Ringer Mode auf Silent
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT

            // 3. Setze Ringer und Notification Lautstärke auf 0 (Anrufe stumm)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, 0, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 0, 0)

            // 4. WICHTIG: Stelle sicher, dass STREAM_MUSIC eine hörbare Lautstärke hat!
            // Wenn STREAM_MUSIC zu leise ist (< 30% vom Maximum), setze auf 70% vom Maximum
            val maxMusicVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

            if (currentMusicVolume < maxMusicVolume * 0.3) {
                // Setze auf 70% vom Maximum für gute Hörbarkeit der Tierlaute
                val targetMusicVolume = (maxMusicVolume * 0.7).toInt()
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetMusicVolume, 0)
                android.util.Log.d("WeidmannsheilAudio",
                    "STREAM_MUSIC war zu leise ($currentMusicVolume/$maxMusicVolume), " +
                    "setze auf $targetMusicVolume für Tierlaute")
            } else {
                android.util.Log.d("WeidmannsheilAudio",
                    "STREAM_MUSIC ist OK: $currentMusicVolume/$maxMusicVolume")
            }

        } else {
            // Ghost Mode OFF: Stelle ursprüngliche Werte wieder her
            audioManager.ringerMode = savedRingerMode

            // Stelle alle Lautstärken wieder her
            audioManager.setStreamVolume(AudioManager.STREAM_RING, savedRingerVolume, 0)
            audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, savedNotificationVolume, 0)

            // Stelle auch STREAM_MUSIC wieder her (falls wir ihn verändert haben)
            if (savedMusicVolume > 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, savedMusicVolume, 0)
            }
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
