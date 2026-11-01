package com.example.women_safety_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage

/**
 * Receives the network's delivery reports. A long alert is split into parts,
 * each reported separately, and it only counts once every part has arrived.
 */
class SmsDeliveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val tag = intent.getStringExtra(EXTRA_TAG) ?: return
        val sendId = intent.getStringExtra(EXTRA_SEND_ID) ?: return
        val parts = intent.getIntExtra(EXTRA_PARTS, 1)
        val pdu = intent.getByteArrayExtra("pdu") ?: return
        val format = intent.getStringExtra("format") ?: return
        val status = SmsMessage.createFromPdu(pdu, format)?.status ?: return
        // Below this, the report means "received". Anything else proves nothing.
        if (status >= FIRST_NOT_RECEIVED_STATUS) return

        val confirmed = (confirmedParts[sendId] ?: 0) + 1
        if (confirmed < parts) {
            confirmedParts[sendId] = confirmed
            return
        }
        confirmedParts.remove(sendId)
        MainActivity.reportDelivered(tag)
    }

    companion object {
        const val EXTRA_TAG = "tag"
        const val EXTRA_SEND_ID = "sendId"
        const val EXTRA_PARTS = "parts"
        private const val FIRST_NOT_RECEIVED_STATUS = 0x20
        private val confirmedParts = mutableMapOf<String, Int>()
    }
}
