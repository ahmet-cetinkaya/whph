package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class TasksRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks: org.json.JSONArray? = null

    override fun onCreate() {
        // Data is loaded in onDataSetChanged
    }

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val dataString = widgetData?.getString("widget_data", null)

        if (dataString != null) {
            try {
                val data = JSONObject(dataString)
                tasks = data.optJSONArray("tasks")
            } catch (e: Exception) {
                tasks = null
            }
        }
    }

    override fun onDestroy() {
        tasks = null
    }

    override fun getCount(): Int {
        return tasks?.length() ?: 0
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)

        if (tasks == null || position >= tasks!!.length()) return views

        try {
            val task = tasks!!.getJSONObject(position)
            val taskId = task.optString("id", "")
            val title = task.optString("title", "Unknown task")
            val isCompleted = task.optBoolean("isCompleted", false)

            views.setTextViewText(R.id.task_title, title)

            if (isCompleted) {
                views.setImageViewResource(R.id.task_checkbox, R.drawable.ic_check_box)
            } else {
                views.setImageViewResource(R.id.task_checkbox, R.drawable.ic_check_box_outline)
            }

            // Fill Intent
            val fillInIntent = Intent()
            val uri = Uri.parse("whph://widget?action=toggle_task&itemId=$taskId")
            fillInIntent.data = uri
            views.setOnClickFillInIntent(R.id.task_checkbox, fillInIntent)
            
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
