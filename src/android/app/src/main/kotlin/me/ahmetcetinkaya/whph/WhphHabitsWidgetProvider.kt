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

            // Get widget data from HomeWidget plugin
            val widgetData = HomeWidgetPlugin.getData(context)
            val dataString = widgetData?.getString("widget_data", null)

            if (dataString != null) {
                val data = JSONObject(dataString)
                val habits = data.optJSONArray("habits")
                val habitCount = habits?.length() ?: 0

                setupHabitItems(context, views, habits, habitCount)

                // Show/hide all habits completed icon
                var showCompletedIcon = false
                if (habitCount == 0) {
                    // No habits at all: show completed icon
                    showCompletedIcon = true
                } else {
                    // Check if all habits are truly completed (including daily targets)
                    var allCompleted = true
                    if (habits != null) {
                        for (i in 0 until habitCount) {
                            val habit = habits.getJSONObject(i)
                            val hasGoal = habit.optBoolean("hasGoal", false)
                            val dailyTarget = habit.optInt("dailyTarget", 1)
                            val currentCompletionCount = habit.optInt("currentCompletionCount", 0)
                            val isDailyGoalMet = habit.optBoolean("isDailyGoalMet", false)
                            val targetFrequency = habit.optInt("targetFrequency", 1)
                            val periodDays = habit.optInt("periodDays", 1)
                            
                            // Check if habit is completed based on goal type
                            val isHabitCompleted = if (hasGoal) {
                                if (periodDays > 1) {
                                    // Period-based goal: check if isDailyGoalMet (already calculated for period)
                                    isDailyGoalMet
                                } else if (dailyTarget > 1) {
                                    // Multi-occurrence daily goal: check daily completion
                                    isDailyGoalMet
                                } else {
                                    // Simple daily goal: check if completed today
                                    habit.optBoolean("isCompletedToday", false)
                                }
                            } else {
                                // No goal: check if completed today
                                habit.optBoolean("isCompletedToday", false)
                            }
                            
                            if (!isHabitCompleted) {
                                allCompleted = false
                                break
                            }
                        }
                    } else {
                        allCompleted = false
                    }
                    if (allCompleted) {
                        showCompletedIcon = true
                    }
                }
                if (showCompletedIcon) {
                    views.setViewVisibility(R.id.all_habits_completed_icon, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.all_habits_completed_icon, android.view.View.GONE)
                }
            } else {
                // No data available yet - show placeholder content
                setupHabitItems(context, views, null, 0)
                // Hide completed icon when no data
                views.setViewVisibility(R.id.all_habits_completed_icon, android.view.View.GONE)
            }
            
            // Set up click to open app only on header area
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
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
            
            // Set timestamp
            val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.habits_widget_timestamp, currentTime)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)

        } catch (e: Exception) {
            Log.e(TAG, "Error updating habits widget $appWidgetId", e)
        }
    }

    private fun setupHabitItems(context: Context, views: RemoteViews, habits: org.json.JSONArray?, habitCount: Int) {
        // Habit item IDs and their corresponding checkbox, title, and progress IDs
        val habitItemIds = arrayOf(R.id.habit_item_1, R.id.habit_item_2, R.id.habit_item_3, R.id.habit_item_4, R.id.habit_item_5)
        val habitCheckboxIds = arrayOf(R.id.habit_checkbox_1, R.id.habit_checkbox_2, R.id.habit_checkbox_3, R.id.habit_checkbox_4, R.id.habit_checkbox_5)
        val habitTitleIds = arrayOf(R.id.habit_title_1, R.id.habit_title_2, R.id.habit_title_3, R.id.habit_title_4, R.id.habit_title_5)
        val habitProgressIds = arrayOf(R.id.habit_progress_1, R.id.habit_progress_2, R.id.habit_progress_3, R.id.habit_progress_4, R.id.habit_progress_5)

        // Setup each habit item
        for (i in 0 until 5) {
            if (i < habitCount) {
                val habit = habits!!.getJSONObject(i)
                val habitId = habit.optString("id", "")
                val name = habit.optString("name", "Unknown habit")
                val isCompletedToday = habit.optBoolean("isCompletedToday", false)
                val hasGoal = habit.optBoolean("hasGoal", false)
                val dailyTarget = habit.optInt("dailyTarget", 1)
                val currentCompletionCount = habit.optInt("currentCompletionCount", 0)
                val isDailyGoalMet = habit.optBoolean("isDailyGoalMet", false)

                // Show the item
                views.setViewVisibility(habitItemIds[i], android.view.View.VISIBLE)
                views.setTextViewText(habitTitleIds[i], name)

                // Set checkbox appearance based on completion status and goals
                if (hasGoal && dailyTarget > 1) {
                    // Multi-occurrence habit with custom goals - prevent premature completion display
                    when {
                        currentCompletionCount == 0 -> {
                            views.setImageViewResource(habitCheckboxIds[i], R.drawable.ic_check_box_outline)
                        }
                        currentCompletionCount < dailyTarget -> {
                            // Show progress icon, never the completed icon until truly complete
                            views.setImageViewResource(habitCheckboxIds[i], R.drawable.ic_add)
                        }
                        currentCompletionCount >= dailyTarget -> {
                            // When daily target is reached, show completed icon
                            views.setImageViewResource(habitCheckboxIds[i], R.drawable.ic_check_box)
                        }
                    }
                    
                    // Show progress badge for multi-occurrence habits when there's progress
                    if (currentCompletionCount > 0 && dailyTarget > 1) {
                        views.setViewVisibility(habitProgressIds[i], android.view.View.VISIBLE)
                        views.setTextViewText(habitProgressIds[i], "$currentCompletionCount/$dailyTarget")
                        
                        // Set progress badge color based on completion status
                        val textColor = when {
                            currentCompletionCount >= dailyTarget -> context.getColor(R.color.success_color) // Green - completed
                            currentCompletionCount > 0 -> context.getColor(R.color.warning_color) // Amber - in progress
                            else -> context.getColor(R.color.widget_text_secondary) // Gray - not started
                        }
                        views.setTextColor(habitProgressIds[i], textColor)
                    } else {
                        views.setViewVisibility(habitProgressIds[i], android.view.View.GONE)
                    }
                } else {
                    // Simple habit behavior
                    if (isCompletedToday) {
                        views.setImageViewResource(habitCheckboxIds[i], R.drawable.ic_check_box)
                    } else {
                        views.setImageViewResource(habitCheckboxIds[i], R.drawable.ic_check_box_outline)
                    }
                    
                    // Hide progress badge for simple habits
                    views.setViewVisibility(habitProgressIds[i], android.view.View.GONE)
                }

                // Set up click listener for the checkbox using HomeWidget background intent
                val uri = Uri.parse("whph://widget?action=toggle_habit&itemId=$habitId")
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)

                views.setOnClickPendingIntent(habitCheckboxIds[i], backgroundIntent)
            } else {
                // Hide unused items
                views.setViewVisibility(habitItemIds[i], android.view.View.GONE)
            }
        }
    }
}
