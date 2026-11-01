package com.example.women_safety_app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        // The SOS and Safe Walk timers live in Dart, so Dart must outlive this
        // screen. The foreground service keeps the process running when the
        // activity is destroyed; a new activity then reattaches to this engine,
        // rather than starting a second copy of the app that would alert twice.
        private var engine: FlutterEngine? = null
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return engine ?: FlutterEngine(context.applicationContext).also {
            it.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
            engine = it
        }
    }

    override fun shouldDestroyEngineWithHost() = false

    // Back on the first screen hides the app instead of closing it.
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> sendSms(
                        call.argument<String>("phone")!!,
                        call.argument<String>("message")!!,
                        result,
                    )
                    "maxAlarmVolume" -> {
                        val audio = applicationContext
                            .getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audio.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            0,
                        )
                        result.success(null)
                    }
                    "startProtection" -> result.success(startProtection())
                    "stopProtection" -> {
                        stopService(Intent(applicationContext, SafetyForegroundService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Returns false rather than crashing if Android refuses, which it does
     * without location permission or while the app is fully in the background;
     * the Dart side tries again.
     */
    private fun startProtection(): Boolean {
        val context = applicationContext
        val hasLocation = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!hasLocation) return false
        return try {
            context.startForegroundService(Intent(context, SafetyForegroundService::class.java))
            true
        } catch (e: IllegalStateException) {
            false
        }
    }

    /**
     * Sends one SMS (split into parts if long) and replies once the radio has
     * reported on every part, so "sent" means the network really accepted it.
     */
    private fun sendSms(phone: String, message: String, result: MethodChannel.Result) {
        val context = applicationContext
        if (context.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.success("no_permission")
            return
        }

        val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = manager.divideMessage(message)
        val action = "$packageName.SMS_SENT.${UUID.randomUUID()}"
        val handler = Handler(Looper.getMainLooper())
        var remaining = parts.size
        var failed = false
        var replied = false
        lateinit var receiver: BroadcastReceiver

        fun reply(status: String) {
            if (replied) return
            replied = true
            handler.removeCallbacksAndMessages(null)
            context.unregisterReceiver(receiver)
            result.success(status)
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(receiverContext: Context, intent: Intent) {
                if (resultCode != Activity.RESULT_OK) failed = true
                remaining--
                if (remaining == 0) reply(if (failed) "failed" else "sent")
            }
        }

        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        handler.postDelayed({ reply("failed") }, 60_000)

        val sentIntents = ArrayList(
            parts.indices.map { index ->
                PendingIntent.getBroadcast(
                    context,
                    index,
                    Intent(action).setPackage(packageName),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
                )
            },
        )
        try {
            manager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
        } catch (e: Exception) {
            reply("failed")
        }
    }
}
