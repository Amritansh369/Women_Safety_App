package com.example.women_safety_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon

/** The SOS shortcut shared by every entry point, and the app's notifications. */
object SafetyNotices {
    private const val CHANNEL_ID = "safety_notices"
    private const val QUICK_SOS_ID = 7422
    private const val NOTICE_ID = 7423

    fun sosIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        1,
        Intent(context, SosShortcutActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun sosAction(context: Context): Notification.Action = Notification.Action.Builder(
        Icon.createWithResource(context, R.drawable.ic_notification),
        "Start SOS",
        sosIntent(context),
    ).build()

    /** Stays on the lock screen, so an SOS is reachable without unlocking. */
    fun showQuickSos(context: Context) {
        val notification = builder(context)
            .setContentTitle("SafeHer")
            .setContentText("Press Start SOS for help. You can still cancel.")
            .setContentIntent(openApp(context))
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(sosAction(context))
            .build()
        manager(context).notify(QUICK_SOS_ID, notification)
    }

    fun hideQuickSos(context: Context) = manager(context).cancel(QUICK_SOS_ID)

    fun post(context: Context, title: String, text: String) {
        val notification = builder(context)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .build()
        manager(context).notify(NOTICE_ID, notification)
    }

    private fun builder(context: Context): Notification.Builder {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Safety notices",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { setSound(null, null) }
        manager(context).createNotificationChannel(channel)
        return Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE,
    )

    private fun manager(context: Context) =
        context.getSystemService(NotificationManager::class.java)
}
