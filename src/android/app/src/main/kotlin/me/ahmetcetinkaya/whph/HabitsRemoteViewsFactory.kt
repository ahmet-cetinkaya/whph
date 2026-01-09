package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class HabitsRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var habits: org.json.JSONArray? = null

    override fun onCreate() {
        // Data is loaded in onDataSetChanged
    }

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val dataString = widgetData?.getString("widget_data", null)

        if (dataString != null) {
            try {
                val data = JSONObject(dataString)
                habits = data.optJSONArray("habits")
            } catch (e: Exception) {
                habits = null
            }
        }
    }

    override fun onDestroy() {
        habits = null
    }

    override fun getCount(): Int {
        return habits?.length() ?: 0
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_habit_item)

        if (habits == null || position >= habits!!.length()) return views

        try {
            val habit = habits!!.getJSONObject(position)
            val habitId = habit.optString("id", "")
            val name = habit.optString("name", "Unknown habit")
            val isCompletedToday = habit.optBoolean("isCompletedToday", false)
            val hasGoal = habit.optBoolean("hasGoal", false)
            val dailyTarget = habit.optInt("dailyTarget", 1)
            val currentCompletionCount = habit.optInt("currentCompletionCount", 0)
            val isDailyGoalMet = habit.optBoolean("isDailyGoalMet", false)
            val periodDays = habit.optInt("periodDays", 1)

            views.setTextViewText(R.id.habit_title, name)

            // Logic copied from Provider to determine icon
            if (hasGoal && dailyTarget > 1) {
                when {
                    currentCompletionCount == 0 -> {
                        views.setImageViewResource(R.id.habit_checkbox, R.drawable.ic_check_box_outline)
                    }
                    currentCompletionCount < dailyTarget -> {
                        views.setImageViewResource(R.id.habit_checkbox, R.drawable.ic_add)
                    }
                    currentCompletionCount >= dailyTarget -> {
                        views.setImageViewResource(R.id.habit_checkbox, R.drawable.ic_check_box)
                    }
                }

                if (currentCompletionCount > 0 && dailyTarget > 1) {
                    views.setViewVisibility(R.id.habit_progress, View.VISIBLE)
                    views.setTextViewText(R.id.habit_progress, "$currentCompletionCount/$dailyTarget")
                    
                    val textColor = when {
                        currentCompletionCount >= dailyTarget -> context.getColor(R.color.success_color)
                        currentCompletionCount > 0 -> context.getColor(R.color.warning_color)
                        else -> context.getColor(R.color.widget_text_secondary)
                    }
                    views.setTextColor(R.id.habit_progress, textColor)
                } else {
                    views.setViewVisibility(R.id.habit_progress, View.GONE)
                }
            } else {
                if (isCompletedToday) {
                    views.setImageViewResource(R.id.habit_checkbox, R.drawable.ic_check_box)
                } else {
                    views.setImageViewResource(R.id.habit_checkbox, R.drawable.ic_check_box_outline)
                }
                views.setViewVisibility(R.id.habit_progress, View.GONE)
            }

            // Fill Intent
            val fillInIntent = Intent()
            val uri = Uri.parse("whph://widget?action=toggle_habit&itemId=$habitId")
            // HomeWidgetBackgroundIntent creates a PendingIntent, but we need an Intent for setOnClickFillInIntent
            // We can't use HomeWidgetBackgroundIntent directly here because fillInIntent must be a plain Intent
            // that adds extras to the PendingIntent template set on the ListView.
            
            // However, HomeWidget's architecture relies on BroadcastReceivers. 
            // The template pending intent should target HomeWidgetBackgroundReceiver (or the Provider).
            // Let's look at how HomeWidgetBackgroundIntent works. It usually sends a broadcast.
            
            // We need to construct the intent exactly as HomeWidget expects it.
            // Since we can't easily use HomeWidgetBackgroundIntent.getBroadcast in a fillInIntent context 
            // (it returns a PendingIntent), we need to manually construct the Intent that the BroadcastReceiver expects.
            
            // Actually, simpler approach:
            // The pending intent template on the list view will be a Broadcast to HomeWidgetBackgroundReceiver.
            // The fillInIntent will add the data URI.
            fillInIntent.data = uri
            views.setOnClickFillInIntent(R.id.habit_checkbox, fillInIntent)
            
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return false
    }
}
