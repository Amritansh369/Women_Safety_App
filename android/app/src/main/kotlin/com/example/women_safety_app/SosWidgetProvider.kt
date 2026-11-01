package com.example.women_safety_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** A home-screen SOS button. It starts the countdown, so a stray tap can be cancelled. */
class SosWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.widget_sos)
        views.setOnClickPendingIntent(R.id.widget_sos, SafetyNotices.sosIntent(context))
        manager.updateAppWidget(ids, views)
    }
}
