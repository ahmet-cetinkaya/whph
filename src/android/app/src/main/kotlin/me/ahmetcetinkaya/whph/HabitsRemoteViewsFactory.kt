package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class HabitsRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    companion object {
        private const val TAG = "HabitsRemoteViewsFactory"
    }
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

        val currentHabits = habits ?: return views
        if (position >= currentHabits.length()) return views

        try {
            val habit = currentHabits.getJSONObject(position)
            val habitId = habit.optString("id", "")
            val name = habit.optString("name", "Unknown habit")
            val isCompletedToday = habit.optBoolean("isCompletedToday", false)
            val hasGoal = habit.optBoolean("hasGoal", false)
            val dailyTarget = habit.optInt("dailyTarget", 1)
            val currentCompletionCount = habit.optInt("currentCompletionCount", 0)

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
            fillInIntent.data = uri
            views.setOnClickFillInIntent(R.id.habit_checkbox, fillInIntent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing habit at position $position", e)
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
        return try {
            habits?.getJSONObject(position)?.getString("id")?.hashCode()?.toLong() ?: position.toLong()
        } catch (e: Exception) {
            position.toLong()
        }
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
