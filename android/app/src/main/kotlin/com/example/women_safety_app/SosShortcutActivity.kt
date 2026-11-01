package com.example.women_safety_app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Where the tile, widget and notification button land. MainActivity has to be
 * exported, so any installed app could open it; this one isn't, so only SafeHer's
 * own shortcuts can ask for an SOS.
 */
class SosShortcutActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MainActivity.requestSos()
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
        finish()
    }
}
