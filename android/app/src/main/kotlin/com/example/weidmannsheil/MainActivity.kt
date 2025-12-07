package com.example.weidmannsheil

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.weidmannsheil/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGhostMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val success = setGhostMode(enable)
                    result.success(success)
                }
                "getRingerMode" -> {
                    val status = getRingerMode()
                    result.success(status)
                }
                "hasDoNotDisturbPermission" -> {
                    val hasPermission = hasDoNotDisturbPermission()
                    result.success(hasPermission)
                }
                "requestDoNotDisturbPermission" -> {
                    requestDoNotDisturbPermission()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasDoNotDisturbPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return notificationManager.isNotificationPolicyAccessGranted
        }
        return true // Auf älteren Android-Versionen nicht benötigt
    }

    private fun requestDoNotDisturbPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            startActivity(intent)
        }
    }

    private fun setGhostMode(enable: Boolean): Boolean {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Prüfen ob wir die Permission haben
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!notificationManager.isNotificationPolicyAccessGranted) {
                return false // Keine Permission
            }
        }

        if (enable) {
            // Ghost Mode ON: Do Not Disturb aktivieren
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            } else {
                // Fallback für ältere Android-Versionen
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            }
        } else {
            // Ghost Mode OFF: Do Not Disturb deaktivieren
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            } else {
                // Fallback für ältere Android-Versionen
                audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            }
        }

        return true // Erfolgreich
    }

    private fun getRingerMode(): String {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return when (notificationManager.currentInterruptionFilter) {
                NotificationManager.INTERRUPTION_FILTER_NONE -> "SILENT"
                NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "PRIORITY"
                NotificationManager.INTERRUPTION_FILTER_ALARMS -> "ALARMS"
                NotificationManager.INTERRUPTION_FILTER_ALL -> "NORMAL"
                else -> "UNKNOWN"
            }
        } else {
            // Fallback für ältere Android-Versionen
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            return when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_SILENT -> "SILENT"
                AudioManager.RINGER_MODE_VIBRATE -> "VIBRATE"
                AudioManager.RINGER_MODE_NORMAL -> "NORMAL"
                else -> "UNKNOWN"
            }
        }
    }
}
