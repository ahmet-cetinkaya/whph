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

class WhphTasksWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "WhphTasksWidgetProvider"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            "REFRESH_TASKS_WIDGET" -> {
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
            val views = RemoteViews(context.packageName, R.layout.whph_tasks_widget)

            // Get widget data from HomeWidget plugin
            val widgetData = HomeWidgetPlugin.getData(context)
            val dataString = widgetData?.getString("widget_data", null)

            if (dataString != null) {
                val data = JSONObject(dataString)
                val tasks = data.optJSONArray("tasks")
                val taskCount = tasks?.length() ?: 0

                setupTaskItems(context, views, tasks, taskCount)

                // Show/hide completed icon
                var showCompletedIcon = false
                if (taskCount == 0) {
                    // No tasks at all: show completed icon
                    showCompletedIcon = true
                } else {
                    // Check if all tasks are completed
                    var allCompleted = true
                    if (tasks != null) {
                        for (i in 0 until taskCount) {
                            val task = tasks.getJSONObject(i)
                            if (!task.optBoolean("isCompleted", false)) {
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
                    views.setViewVisibility(R.id.all_tasks_completed_icon, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.all_tasks_completed_icon, android.view.View.GONE)
                }
            } else {
                // No data: show completed icon
                views.setViewVisibility(R.id.all_tasks_completed_icon, android.view.View.VISIBLE)
            }
            
            // Set up click to open app only on header area
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.tasks_widget_header, pendingIntent)
            
            // Set up refresh button click listener
            val refreshIntent = Intent(context, WhphTasksWidgetProvider::class.java).apply {
                action = "REFRESH_TASKS_WIDGET"
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.tasks_widget_refresh_button, refreshPendingIntent)
            
            // Set timestamp
            val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.tasks_widget_timestamp, currentTime)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)

        } catch (e: Exception) {
            Log.e(TAG, "Error updating tasks widget $appWidgetId", e)
        }
    }

    private fun setupTaskItems(context: Context, views: RemoteViews, tasks: org.json.JSONArray?, taskCount: Int) {
        // Task item IDs and their corresponding checkbox and title IDs
        val taskItemIds = arrayOf(R.id.task_item_1, R.id.task_item_2, R.id.task_item_3, R.id.task_item_4, R.id.task_item_5)
        val taskCheckboxIds = arrayOf(R.id.task_checkbox_1, R.id.task_checkbox_2, R.id.task_checkbox_3, R.id.task_checkbox_4, R.id.task_checkbox_5)
        val taskTitleIds = arrayOf(R.id.task_title_1, R.id.task_title_2, R.id.task_title_3, R.id.task_title_4, R.id.task_title_5)

        // Setup each task item
        for (i in 0 until 5) {
            if (i < taskCount) {
                val task = tasks!!.getJSONObject(i)
                val taskId = task.optString("id", "")
                val title = task.optString("title", "Unknown task")
                val isCompleted = task.optBoolean("isCompleted", false)

                // Show the item
                views.setViewVisibility(taskItemIds[i], android.view.View.VISIBLE)
                views.setTextViewText(taskTitleIds[i], title)

                // Set checkbox appearance based on completion status
                if (isCompleted) {
                    views.setImageViewResource(taskCheckboxIds[i], R.drawable.ic_check_box)
                } else {
                    views.setImageViewResource(taskCheckboxIds[i], R.drawable.ic_check_box_outline)
                }

                // Set up click listener for the checkbox using HomeWidget background intent
                val uri = Uri.parse("whph://widget?action=toggle_task&itemId=$taskId")
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)

                views.setOnClickPendingIntent(taskCheckboxIds[i], backgroundIntent)
            } else {
                // Hide unused items
                views.setViewVisibility(taskItemIds[i], android.view.View.GONE)
            }
        }
    }
}
