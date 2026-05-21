package me.ahmetcetinkaya.whph

import android.content.Context
import android.util.Log
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

abstract class BaseRemoteViewsFactory(
  private val context: Context,
  private val dataArrayKey: String,
) : RemoteViewsService.RemoteViewsFactory {
  companion object {
    private const val TAG = "BaseRemoteViewsFactory"
  }

  protected var items: JSONArray? = null

  override fun onCreate() = Unit

  override fun onDataSetChanged() {
    val widgetData = HomeWidgetPlugin.getData(context)
    val dataString = widgetData?.getString("widget_data", null)

    if (dataString != null) {
      try {
        val data = JSONObject(dataString)
        items = data.optJSONArray(dataArrayKey)
      } catch (e: Exception) {
        Log.e(TAG, "Failed to parse widget data for $dataArrayKey", e)
        items = null
      }
    }
  }

  override fun onDestroy() {
    items = null
  }

  override fun getCount(): Int = items?.length() ?: 0

  protected fun isValidPosition(position: Int): Boolean {
    val currentItems = items ?: return false
    return position < currentItems.length()
  }

  protected fun getItem(position: Int): JSONObject? {
    if (!isValidPosition(position)) return null
    return try {
      items?.getJSONObject(position)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to get item at position $position", e)
      null
    }
  }

  override fun getItemId(position: Int): Long =
    try {
      val idString = items?.getJSONObject(position)?.getString("id")
      idString?.let {
        // Use a more stable hash by combining string hashCode with position
        // This reduces collision risk when item IDs have similar hash values
        (it.hashCode().toLong() shl 32) or (position.toLong() and 0xFFFFFFFFL)
      } ?: position.toLong()
    } catch (e: Exception) {
      position.toLong()
    }

  override fun hasStableIds(): Boolean = true
}
