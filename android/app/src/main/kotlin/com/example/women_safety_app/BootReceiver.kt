package com.example.women_safety_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONException
import org.json.JSONObject

/**
 * Tells the user what a restart stopped. Android doesn't let an app start a
 * location service from boot without "all the time" location, which SafeHer
 * doesn't ask for, so the protection itself returns when the app is opened.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        // Where the shared_preferences plugin keeps the app's saved state.
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settings = try {
            JSONObject(prefs.getString("flutter.app_settings", null) ?: "{}")
        } catch (e: JSONException) {
            JSONObject()
        }

        if (settings.optBoolean("quickSos")) SafetyNotices.showQuickSos(context)

        val message = when {
            prefs.contains("flutter.active_incident") ->
                "Your SOS stopped when the phone restarted. Open SafeHer to resume it."
            prefs.contains("flutter.safe_walk") ->
                "Your Safe Walk stopped when the phone restarted. Open SafeHer to resume it."
            settings.optBoolean("shakeEnabled") && settings.optBoolean("guardianMode") ->
                "Guardian mode is off until you open SafeHer."
            else -> return
        }
        SafetyNotices.post(context, "Open SafeHer to stay protected", message)
    }
}
