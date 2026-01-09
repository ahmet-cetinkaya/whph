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

            // Get widget data to check if we should show 'All Completed' icon separate from list
            // Note: with ListView setEmptyView handling "no pending habits", the 'all completed' icon logic 
            // might need adjustment effectively.
            // If the list is empty because everything is completed, setEmptyView will show.
            // But we want a specific "Success" icon if everything is done vs just "No habits".
            // The previous logic checked specific flags. 
            // For now, let's rely on the Flutter side to provide an empty list if completed 
            // and maybe we can show the icon if count is 0 but we know habits exist?
            // Actually, best to simplify: Let the Flutter side pass a flag "showSuccessIcon".
            // If we want to keep it simple for now, we can rely on empty view text "No pending habits".
            // However, the original PRD mentioned "All habits completed icon".
            // Let's check the data to toggle the icon visibility OVER/INSTEAD of the list or empty view?
            // RemoteViews limitations: we can't easily check adapter count here without binding.
            
            // Let's re-read the data locally just for the header/footer visibility logic
            // (The adapter will do its own reading for the list)
            val widgetData = HomeWidgetPlugin.getData(context)
            val dataString = widgetData?.getString("widget_data", null)
            
            var showCompletedIcon = false
            if (dataString != null) {
                val data = JSONObject(dataString)
                val habits = data.optJSONArray("habits")
                val habitCount = habits?.length() ?: 0
                
                // If we have habits but filtered them all out in the list (e.g. all completed), 
                // the list ID approach handles items. 
                // But the "All Done" icon is a separate view superimposed or replacing.
                
                // If habitCount is 0, it means no pending habits.
                // We should check if we should show the success icon. 
                // The previous logic was complex about "isDailyGoalMet". 
                // Ideally, the Flutter side should give us a simple boolean "allHabitsCompleted".
                // But we can stick to previous logic: if habitCount (pending habits) is 0, show icon?
                // Wait, the aggregated data passed to widget ONLY contains pending items?
                // In the previous code, `setupHabitItems` iterated over the passed items.
                // If the list passed from Flutter IS the list of PENDING items, then empty list = all done.
                // Let's assume Flutter sends only what needs to be shown.
                
                if (habitCount == 0) {
                     showCompletedIcon = true
                }
            } else {
                 // No data?
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
            
            // Set up item click title template (Broadcast to HomeWidget)
            // We use HomeWidgetBackgroundIntent to get the PendingIntent template.
            // The fillInIntent in the factory will provide the specific data URI.
            val templateIntent = Intent(context, WhphHabitsWidgetProvider::class.java)
            // We need a unique action or it might conflict? 
            // Actually HomeWidgetBackgroundIntent uses a specific receiver.
            // Let's look at how we did it before:
            // val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)
            // We can't use getBroadcast here easily for a TEMPLATE because getBroadcast returns a PendingIntent.
            // Views.setPendingIntentTemplate(R.id.list, pendingIntentTemplate)
            
            // The pendingIntentTemplate should be generic. The fillInIntent adds the extras/data.
            // HomeWidgetBackgroundReceiver is where we want to go.
            // But `HomeWidgetBackgroundIntent.getBroadcast` creates a PendingIntent pointing to `HomeWidgetBackgroundReceiver`.
            // We can create a "base" PendingIntent that points to that receiver.
            // The Uri will be filled in by the item.
            
            // Constructing a PendingIntent that targets the HomeWidgetBackgroundReceiver
            val bgIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java)
            bgIntent.action = "es.antonborri.home_widget.action.BACKGROUND"
            
            val pendingIntentTemplate = PendingIntent.getBroadcast(
                context, 
                0, 
                bgIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE // Mutable to allow fillIn?
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

    private fun setupHabitItems(context: Context, views: RemoteViews, habits: org.json.JSONArray?, habitCount: Int) {
        // Deprecated: Logic moved to HabitsRemoteViewsFactory
    }
}
