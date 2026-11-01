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
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.view.WindowManager
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
        private var channel: MethodChannel? = null
        private var current: MainActivity? = null
        private var sosRequested = false

        /** Called by SosShortcutActivity, and only by it. */
        fun requestSos() {
            sosRequested = true
            current?.showOverLockScreen(true)
        }

        fun reportDelivered(tag: String) {
            channel?.invokeMethod("smsDelivered", tag)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (sosRequested) showOverLockScreen(true)
        super.onCreate(savedInstanceState)
        current = this
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        if (sosRequested) channel?.invokeMethod("sosRequested", null)
    }

    private fun showOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            @Suppress("DEPRECATION")
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
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
        val device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeher/device")
        channel = device
        device.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> sendSms(
                        call.argument<String>("phone")!!,
                        call.argument<String>("message")!!,
                        call.argument<String>("deliveryTag"),
                        result,
                    )
                    "consumeSosRequest" -> {
                        result.success(sosRequested)
                        sosRequested = false
                    }
                    "leaveLockScreen" -> {
                        showOverLockScreen(false)
                        result.success(null)
                    }
                    "setQuickSos" -> {
                        if (call.argument<Boolean>("enabled") == true) {
                            SafetyNotices.showQuickSos(applicationContext)
                        } else {
                            SafetyNotices.hideQuickSos(applicationContext)
                        }
                        result.success(null)
                    }
                    "postNotice" -> {
                        SafetyNotices.post(
                            applicationContext,
                            call.argument<String>("title")!!,
                            call.argument<String>("text")!!,
                        )
                        result.success(null)
                    }
                    "batteryLevel" -> {
                        val battery = applicationContext
                            .getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        result.success(
                            if (battery.isCharging) {
                                null
                            } else {
                                battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                            },
                        )
                    }
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
    private fun sendSms(
        phone: String,
        message: String,
        deliveryTag: String?,
        result: MethodChannel.Result,
    ) {
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
            manager.sendMultipartTextMessage(
                phone,
                null,
                parts,
                sentIntents,
                deliveryTag?.let { deliveryIntents(it, parts.size) },
            )
        } catch (e: Exception) {
            reply("failed")
        }
    }

    // Mutable because the radio adds the report to the intent. It can't be
    // redirected: the intent names SmsDeliveryReceiver explicitly.
    private fun deliveryIntents(tag: String, parts: Int): ArrayList<PendingIntent> {
        val context = applicationContext
        val sendId = UUID.randomUUID().toString()
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        return ArrayList(
            (0 until parts).map { index ->
                PendingIntent.getBroadcast(
                    context,
                    (sendId.hashCode() and 0xFFFF) * 100 + index,
                    Intent(context, SmsDeliveryReceiver::class.java)
                        .putExtra(SmsDeliveryReceiver.EXTRA_TAG, tag)
                        .putExtra(SmsDeliveryReceiver.EXTRA_SEND_ID, sendId)
                        .putExtra(SmsDeliveryReceiver.EXTRA_PARTS, parts),
                    PendingIntent.FLAG_ONE_SHOT or mutable,
                )
            },
        )
    }
}
