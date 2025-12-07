package com.example.weidmannsheil

import android.content.Context
import android.media.AudioManager
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
                    setGhostMode(enable)
                    result.success(null)
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
            // Ghost Mode ON: Mute ringer and notifications, but keep media stream
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        } else {
            // Ghost Mode OFF: Restore normal ringer mode
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
        }
    }
}
