package me.ahmetcetinkaya.whph

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class WhphHabitsWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "WhphHabitsWidgetProvider"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            "REFRESH_HABITS_WIDGET" -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    updateAppWidget(context, appWidgetManager, appWidgetId)

                    // Trigger a sync to get fresh data
                    try {
                        val syncIntent = Intent("me.ahmetcetinkaya.whph.SYNC_TRIGGER")
                        context.sendBroadcast(syncIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending sync trigger", e)
                    }
                }
            }
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        try {
            val views = RemoteViews(context.packageName, R.layout.whph_habits_widget)

            // Bind the widget to the RemoteViewsService
            val intent = Intent(context, WhphWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("is_habits_widget", true)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.habits_widget_list, intent)
            views.setEmptyView(R.id.habits_widget_list, R.id.habits_empty_view)

            // Flutter sends only pending habits to the widget. Empty list means all habits are completed.
            val widgetData = HomeWidgetPlugin.getData(context)
            val dataString = widgetData?.getString("widget_data", null)

            var showCompletedIcon = false
            if (dataString != null) {
                val data = JSONObject(dataString)
                val habits = data.optJSONArray("habits")
                val habitCount = habits?.length() ?: 0

                if (habitCount == 0) {
                     showCompletedIcon = true
                }
            }

            if (showCompletedIcon) {
                views.setViewVisibility(R.id.all_habits_completed_icon, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.habits_widget_list, android.view.View.GONE)
                views.setViewVisibility(R.id.habits_empty_view, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.all_habits_completed_icon, android.view.View.GONE)
                views.setViewVisibility(R.id.habits_widget_list, android.view.View.VISIBLE)
            }
            
            // Set up click to open app only on header area
            val mainIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.habits_widget_header, pendingIntent)
            
            // Set up refresh button click listener
            val refreshIntent = Intent(context, WhphHabitsWidgetProvider::class.java).apply {
                action = "REFRESH_HABITS_WIDGET"
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.habits_widget_refresh_button, refreshPendingIntent)

            // Set up item click template - the PendingIntent template targets HomeWidgetBackgroundReceiver
            // and the fillInIntent in the factory will provide the specific data URI.
            val bgIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java)
            bgIntent.action = "es.antonborri.home_widget.action.BACKGROUND"
            
            val pendingIntentTemplate = PendingIntent.getBroadcast(
                context,
                0,
                bgIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.habits_widget_list, pendingIntentTemplate)

            // Set timestamp
            val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.habits_widget_timestamp, currentTime)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.habits_widget_list)

        } catch (e: Exception) {
            Log.e(TAG, "Error updating habits widget $appWidgetId", e)
        }
    }
}
