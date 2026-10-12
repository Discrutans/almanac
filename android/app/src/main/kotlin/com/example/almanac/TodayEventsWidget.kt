package com.example.almanac

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class TodayEventsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateAll(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        const val PREFS = "almanac_today_widget"
        const val KEY_TITLE = "title"
        const val KEY_LINES = "lines"

        fun updateAll(
            context: Context,
            appWidgetManager: AppWidgetManager = AppWidgetManager.getInstance(context),
            appWidgetIds: IntArray = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TodayEventsWidget::class.java),
            ),
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = prefs.getString(KEY_TITLE, "Today") ?: "Today"
            val lines = prefs.getString(KEY_LINES, "") ?: ""
            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.today_widget)
                views.setTextViewText(R.id.today_widget_title, title)
                views.setTextViewText(R.id.today_widget_lines, lines)
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launch != null) {
                    val pending = android.app.PendingIntent.getActivity(
                        context,
                        0,
                        launch,
                        android.app.PendingIntent.FLAG_IMMUTABLE or
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    views.setOnClickPendingIntent(R.id.today_widget_root, pending)
                }
                appWidgetManager.updateAppWidget(id, views)
            }
        }
    }
}
