package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONException
import org.json.JSONObject

/** Data class to hold notification information for rescheduling */
data class NotificationData(
  val id: Int,
  val title: String,
  val body: String,
  val payload: String?,
  val triggerTime: Long,
  val reminderId: String?,
  val metadata: String?,
)

/**
 * Helper class to track scheduled reminder IDs and their metadata This allows for better
 * pattern-based cancellation and management of reminders
 */
class ReminderTracker(context: Context) {
  private val TAG = "ReminderTracker"
  private val PREFS_NAME = "whph_reminder_tracker"
  private val KEY_PREFIX = "reminder_"
  private val KEY_NOTIFICATION_DATA_PREFIX = "notif_data_"
  private val KEY_REMINDER_COUNT = "reminder_count"
  private val KEY_REMINDER_IDS = "reminder_ids"

  private val prefs: SharedPreferences =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  /**
   * Track a new reminder in the local storage
   *
   * @param id The notification ID
   * @param reminderId The optional string reminder ID (can be used for pattern matching)
   * @param metadata Additional information about the reminder (task ID, habit ID, etc.)
   */
  fun trackReminder(id: Int, reminderId: String? = null, metadata: String? = null) {
    try {
      val editor = prefs.edit()
      val storageId = reminderId ?: id.toString()

      // Store individual reminder data
      editor.putString("$KEY_PREFIX$id", "$storageId|${metadata ?: ""}")

      // Update the set of all reminder IDs for easy retrieval
      val reminderIds = getReminderIds().toMutableSet()
      reminderIds.add(id.toString())
      editor.putStringSet(KEY_REMINDER_IDS, reminderIds)

      // Update the count
      editor.putInt(KEY_REMINDER_COUNT, reminderIds.size)

      editor.apply()
      Log.d(TAG, "Tracked reminder: ID=$id, reminderID=$reminderId, metadata=$metadata")
    } catch (e: Exception) {
      Log.e(TAG, "Error tracking reminder: ${e.message}")
    }
  }

  /**
   * Track a notification with complete data for rescheduling after reboot
   *
   * @param id The notification ID
   * @param title The notification title
   * @param body The notification body
   * @param payload The notification payload
   * @param triggerTime The time when notification should trigger (in milliseconds)
   * @param reminderId The optional string reminder ID (can be used for pattern matching)
   * @param metadata Additional information about the reminder (task ID, habit ID, etc.)
   */
  fun trackNotification(
    id: Int,
    title: String,
    body: String,
    payload: String?,
    triggerTime: Long,
    reminderId: String? = null,
    metadata: String? = null,
  ) {
    try {
      val editor = prefs.edit()
      val storageId = reminderId ?: id.toString()

      // Store basic reminder data (for pattern matching)
      editor.putString("$KEY_PREFIX$id", "$storageId|${metadata ?: ""}")

      // Store complete notification data (for rescheduling)
      val notificationJson =
        JSONObject().apply {
          put("id", id)
          put("title", title)
          put("body", body)
          put("payload", payload ?: "")
          put("triggerTime", triggerTime)
          put("reminderId", reminderId ?: "")
          put("metadata", metadata ?: "")
        }
      editor.putString("$KEY_NOTIFICATION_DATA_PREFIX$id", notificationJson.toString())

      // Update the set of all reminder IDs for easy retrieval
      val reminderIds = getReminderIds().toMutableSet()
      reminderIds.add(id.toString())
      editor.putStringSet(KEY_REMINDER_IDS, reminderIds)

      // Update the count
      editor.putInt(KEY_REMINDER_COUNT, reminderIds.size)

      editor.apply()
      Log.d(
        TAG,
        "Tracked notification: ID=$id, reminderID=$reminderId, triggerTime=${java.util.Date(triggerTime)}",
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error tracking notification: ${e.message}")
    }
  }

  /**
   * Remove a tracked reminder
   *
   * @param id The notification ID to remove
   */
  fun untrackReminder(id: Int) {
    try {
      val editor = prefs.edit()

      // Remove individual reminder data
      editor.remove("$KEY_PREFIX$id")

      // Remove notification data
      editor.remove("$KEY_NOTIFICATION_DATA_PREFIX$id")

      // Update the set of all reminder IDs
      val reminderIds = getReminderIds().toMutableSet()
      reminderIds.remove(id.toString())
      editor.putStringSet(KEY_REMINDER_IDS, reminderIds)

      // Update the count
      editor.putInt(KEY_REMINDER_COUNT, reminderIds.size)

      editor.apply()
      Log.d(TAG, "Untracked reminder: ID=$id")
    } catch (e: Exception) {
      Log.e(TAG, "Error untracking reminder: ${e.message}")
    }
  }

  /**
   * Get all tracked reminder IDs
   *
   * @return Set of reminder IDs as strings
   */
  fun getReminderIds(): Set<String> {
    return prefs.getStringSet(KEY_REMINDER_IDS, emptySet()) ?: emptySet()
  }

  /**
   * Find all reminder IDs matching a specific pattern
   *
   * @param startsWith Optional prefix pattern
   * @param contains Optional substring pattern
   * @return List of notification IDs that match the criteria
   */
  fun findRemindersByPattern(startsWith: String? = null, contains: String? = null): List<Int> {
    Log.d(TAG, "Searching for reminders with startsWith='$startsWith', contains='$contains'")

    if (startsWith == null && contains == null) {
      val allIds = getReminderIds().mapNotNull { it.toIntOrNull() }
      Log.d(TAG, "No pattern specified, returning all ${allIds.size} reminder IDs")
      return allIds
    }

    val matchingIds = mutableListOf<Int>()
    val allReminderIds = getReminderIds()
    Log.d(TAG, "Total tracked reminders: ${allReminderIds.size}")

    for (id in allReminderIds) {
      try {
        // Get the stored data for this reminder
        val reminderData = prefs.getString("$KEY_PREFIX$id", null) ?: continue
        val parts = reminderData.split("|")

        if (parts.isEmpty()) continue

        val reminderId = parts[0]
        Log.d(TAG, "Checking reminder ID=$id, reminderId='$reminderId'")

        val matches =
          when {
            startsWith != null && contains != null ->
              reminderId.startsWith(startsWith) && reminderId.contains(contains)
            startsWith != null -> reminderId.startsWith(startsWith)
            contains != null -> reminderId.contains(contains)
            else -> false
          }

        if (matches) {
          Log.d(TAG, "✓ Reminder ID=$id matches pattern")
          matchingIds.add(id.toInt())
        } else {
          Log.d(TAG, "✗ Reminder ID=$id does not match pattern")
        }
      } catch (e: Exception) {
        Log.e(TAG, "Error processing reminder ID $id: ${e.message}")
      }
    }

    Log.d(TAG, "Found ${matchingIds.size} matching reminders: $matchingIds")
    return matchingIds
  }

  /** Clear all tracked reminders */
  fun clearAll() {
    prefs.edit().clear().apply()
    Log.d(TAG, "Cleared all tracked reminders")
  }

  /**
   * Get all stored notification data for rescheduling
   *
   * @return List of NotificationData objects
   */
  fun getAllNotificationData(): List<NotificationData> {
    val notificationDataList = mutableListOf<NotificationData>()
    val reminderIds = getReminderIds()

    for (idStr in reminderIds) {
      try {
        val id = idStr.toInt()
        val notificationDataJson = prefs.getString("$KEY_NOTIFICATION_DATA_PREFIX$id", null)

        if (notificationDataJson != null) {
          val jsonObject = JSONObject(notificationDataJson)
          val notificationData =
            NotificationData(
              id = jsonObject.getInt("id"),
              title = jsonObject.getString("title"),
              body = jsonObject.getString("body"),
              payload = jsonObject.getString("payload").takeIf { it.isNotEmpty() },
              triggerTime = jsonObject.getLong("triggerTime"),
              reminderId = jsonObject.getString("reminderId").takeIf { it.isNotEmpty() },
              metadata = jsonObject.getString("metadata").takeIf { it.isNotEmpty() },
            )
          notificationDataList.add(notificationData)
        } else {
          Log.d(TAG, "No notification data found for ID: $id")
        }
      } catch (e: JSONException) {
        Log.e(TAG, "Error parsing notification data for ID $idStr: ${e.message}")
      } catch (e: NumberFormatException) {
        Log.e(TAG, "Invalid ID format: $idStr")
      }
    }

    Log.d(TAG, "Retrieved ${notificationDataList.size} notification data entries")
    return notificationDataList
  }

  /**
   * Get specific notification data by ID
   *
   * @param id The notification ID
   * @return NotificationData object or null if not found
   */
  fun getNotificationData(id: Int): NotificationData? {
    try {
      val notificationDataJson = prefs.getString("$KEY_NOTIFICATION_DATA_PREFIX$id", null)
      if (notificationDataJson != null) {
        val jsonObject = JSONObject(notificationDataJson)
        return NotificationData(
          id = jsonObject.getInt("id"),
          title = jsonObject.getString("title"),
          body = jsonObject.getString("body"),
          payload = jsonObject.getString("payload").takeIf { it.isNotEmpty() },
          triggerTime = jsonObject.getLong("triggerTime"),
          reminderId = jsonObject.getString("reminderId").takeIf { it.isNotEmpty() },
          metadata = jsonObject.getString("metadata").takeIf { it.isNotEmpty() },
        )
      }
    } catch (e: JSONException) {
      Log.e(TAG, "Error parsing notification data for ID $id: ${e.message}")
    }
    return null
  }
}
