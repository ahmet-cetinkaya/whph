package me.ahmetcetinkaya.whph

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Helper class to track scheduled reminder IDs and their metadata
 * This allows for better pattern-based cancellation and management of reminders
 */
class ReminderTracker(context: Context) {
    private val TAG = "ReminderTracker"
    private val PREFS_NAME = "whph_reminder_tracker"
    private val KEY_PREFIX = "reminder_"
    private val KEY_REMINDER_COUNT = "reminder_count"
    private val KEY_REMINDER_IDS = "reminder_ids"
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * Track a new reminder in the local storage
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
     * Remove a tracked reminder
     * @param id The notification ID to remove
     */
    fun untrackReminder(id: Int) {
        try {
            val editor = prefs.edit()
            
            // Remove individual reminder data
            editor.remove("$KEY_PREFIX$id")
            
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
     * @return Set of reminder IDs as strings
     */
    fun getReminderIds(): Set<String> {
        return prefs.getStringSet(KEY_REMINDER_IDS, emptySet()) ?: emptySet()
    }
    
    /**
     * Find all reminder IDs matching a specific pattern
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
                
                val matches = when {
                    startsWith != null && contains != null -> 
                        reminderId.startsWith(startsWith) && reminderId.contains(contains)
                    startsWith != null -> 
                        reminderId.startsWith(startsWith)
                    contains != null -> 
                        reminderId.contains(contains)
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
    
    /**
     * Clear all tracked reminders
     */
    fun clearAll() {
        prefs.edit().clear().apply()
        Log.d(TAG, "Cleared all tracked reminders")
    }
}