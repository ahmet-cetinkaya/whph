package me.ahmetcetinkaya.whph

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import java.util.*
import kotlin.collections.HashMap

/**
 * Handles app usage statistics with proper filtering for foreground activity only.
 * This implementation aims to match Digital Wellbeing accuracy by:
 * 1. Using both UsageStats and UsageEvents APIs for comprehensive data
 * 2. Tracking actual foreground sessions with start/end events
 * 3. Handling edge cases like sleep mode and missing end events
 * 4. Cross-referencing with system time for precision
 */
class AppUsageStatsHandler(private val context: Context) {
    
    private val usageStatsManager: UsageStatsManager by lazy {
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    }
    
    private val packageManager: PackageManager by lazy {
        context.packageManager
    }
    
    companion object {
        private const val TAG = "AppUsageStatsHandler"
    }
    
    /**
     * Gets accurate foreground usage time for all apps in the specified time range.
     * Uses event-based tracking only to match Digital Wellbeing's methodology more closely.
     */
    fun getAccurateForegroundUsage(startTime: Long, endTime: Long): Map<String, Long> {
        Log.d(TAG, "Getting accurate foreground usage from ${Date(startTime)} to ${Date(endTime)} (${(endTime - startTime) / 1000}s range)")
        
        // Validate time range
        if (endTime <= startTime) {
            Log.e(TAG, "Invalid time range: start=$startTime, end=$endTime")
            return emptyMap()
        }
        
        // Limit to reasonable time range (max 7 days)
        val maxRange = 7 * 24 * 60 * 60 * 1000 // 7 days in milliseconds
        if (endTime - startTime > maxRange) {
            Log.w(TAG, "Time range too large: ${(endTime - startTime) / (1000 * 60 * 60 * 24)} days, limiting to 7 days")
            val limitedStartTime = endTime - maxRange
            return getEventBasedUsage(limitedStartTime, endTime)
        }
        
        try {
            // Use only event-based tracking for consistency with Digital Wellbeing
            val eventBasedUsage = getEventBasedUsage(startTime, endTime)
            
            Log.d(TAG, "Event-based approach returned ${eventBasedUsage.size} apps")
            return eventBasedUsage
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting accurate foreground usage", e)
            return emptyMap()
        }
    }
    
    /**
     * Gets usage data using UsageEvents API for precise session tracking.
     * Rewritten to match Digital Wellbeing's methodology more closely.
     */
    private fun getEventBasedUsage(startTime: Long, endTime: Long): Map<String, Long> {
        val usageMap = HashMap<String, Long>()
        
        try {
            Log.d(TAG, "=== Starting event-based usage tracking ===")
            Log.d(TAG, "Query range: ${Date(startTime)} to ${Date(endTime)} (${(endTime - startTime) / 1000}s)")
            
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            
            // Track app states more precisely - only use primary foreground/background events
            val appStates = HashMap<String, AppState>()
            val completedSessions = HashMap<String, MutableList<UsageSession>>()
            var screenInteractive = true
            
            val event = UsageEvents.Event()
            var eventCount = 0
            
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                eventCount++
                
                if (!isValidUserApp(event.packageName)) {
                    continue
                }
                
                when (event.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        if (screenInteractive) {
                            handleAppForeground(event.packageName, event.timeStamp, appStates, completedSessions, startTime, endTime)
                        }
                    }
                    
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        handleAppBackground(event.packageName, event.timeStamp, appStates, completedSessions, startTime, endTime)
                    }
                    
                    // Only use ACTIVITY events if no recent MOVE_TO events exist
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (screenInteractive) {
                            val currentState = appStates[event.packageName]
                            if (currentState == null || currentState.state != AppState.State.FOREGROUND) {
                                handleAppForeground(event.packageName, event.timeStamp, appStates, completedSessions, startTime, endTime)
                            }
                        }
                    }
                    
                    UsageEvents.Event.ACTIVITY_PAUSED -> {
                        val currentState = appStates[event.packageName]
                        if (currentState?.state == AppState.State.FOREGROUND) {
                            handleAppBackground(event.packageName, event.timeStamp, appStates, completedSessions, startTime, endTime)
                        }
                    }
                    
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                        screenInteractive = false
                        // Close all foreground sessions at screen off time
                        appStates.entries.filter { it.value.state == AppState.State.FOREGROUND }.forEach { (packageName, state) ->
                            finalizeSession(packageName, state.timestamp, event.timeStamp, completedSessions, startTime, endTime)
                            appStates[packageName] = AppState(AppState.State.BACKGROUND, event.timeStamp)
                        }
                        Log.d(TAG, "Screen off: closed all foreground sessions")
                    }
                    
                    UsageEvents.Event.SCREEN_INTERACTIVE -> {
                        screenInteractive = true
                        Log.d(TAG, "Screen on at ${Date(event.timeStamp)}")
                    }
                }
            }
            
            Log.d(TAG, "Processed $eventCount events")
            
            // Close any remaining foreground sessions at the end of the query period
            appStates.entries.filter { it.value.state == AppState.State.FOREGROUND }.forEach { (packageName, state) ->
                finalizeSession(packageName, state.timestamp, endTime, completedSessions, startTime, endTime)
                Log.d(TAG, "Closed remaining session for $packageName at query end")
            }
            
            // Calculate total usage with improved deduplication
            completedSessions.forEach { (packageName, sessions) ->
                val deduplicatedSessions = deduplicateSessions(sessions)
                val totalTime = deduplicatedSessions.sumOf { it.duration }
                if (totalTime > 0) {
                    usageMap[packageName] = totalTime
                    Log.d(TAG, "Event total for $packageName: ${totalTime/1000}s (${sessions.size} raw -> ${deduplicatedSessions.size} deduplicated)")
                }
            }
            
            Log.d(TAG, "=== Event-based tracking complete: ${usageMap.size} apps ===")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in event-based usage tracking", e)
        }
        
        return usageMap
    }
    
    /**
     * Handles app moving to foreground with state validation.
     */
    private fun handleAppForeground(
        packageName: String,
        timestamp: Long,
        appStates: HashMap<String, AppState>,
        completedSessions: HashMap<String, MutableList<UsageSession>>,
        queryStartTime: Long,
        queryEndTime: Long
    ) {
        val currentState = appStates[packageName]
        
        // If app is already in foreground, close the previous session first
        if (currentState?.state == AppState.State.FOREGROUND) {
            finalizeSession(packageName, currentState.timestamp, timestamp, completedSessions, queryStartTime, queryEndTime)
        }
        
        appStates[packageName] = AppState(AppState.State.FOREGROUND, timestamp)
        Log.d(TAG, "App $packageName -> FOREGROUND at ${Date(timestamp)}")
    }
    
    /**
     * Handles app moving to background with state validation.
     */
    private fun handleAppBackground(
        packageName: String,
        timestamp: Long,
        appStates: HashMap<String, AppState>,
        completedSessions: HashMap<String, MutableList<UsageSession>>,
        queryStartTime: Long,
        queryEndTime: Long
    ) {
        val currentState = appStates[packageName]
        
        if (currentState?.state == AppState.State.FOREGROUND) {
            finalizeSession(packageName, currentState.timestamp, timestamp, completedSessions, queryStartTime, queryEndTime)
            appStates[packageName] = AppState(AppState.State.BACKGROUND, timestamp)
            Log.d(TAG, "App $packageName -> BACKGROUND at ${Date(timestamp)}")
        }
    }
    
    /**
     * Finalizes a session with strict validation and proper time boundary handling.
     */
    private fun finalizeSession(
        packageName: String,
        startTime: Long,
        endTime: Long,
        completedSessions: HashMap<String, MutableList<UsageSession>>,
        queryStartTime: Long,
        queryEndTime: Long
    ) {
        // Ensure session is within query boundaries
        val clampedStartTime = maxOf(startTime, queryStartTime)
        val clampedEndTime = minOf(endTime, queryEndTime)
        val duration = clampedEndTime - clampedStartTime
        
        // Strict validation: must be at least 1 second, max 4 hours per session
        if (duration >= 1000 && duration <= 4 * 60 * 60 * 1000) {
            val session = UsageSession(
                startTime = clampedStartTime,
                endTime = clampedEndTime,
                packageName = packageName
            )
            
            completedSessions.getOrPut(packageName) { mutableListOf() }.add(session)
            Log.d(TAG, "Session finalized: $packageName ${session.duration/1000}s (${Date(session.startTime)} - ${Date(session.endTime)})")
        } else {
            Log.d(TAG, "Invalid session rejected: $packageName ${duration/1000}s (original: ${(endTime - startTime)/1000}s)")
        }
    }
    
    /**
     * Deduplicates sessions by merging overlapping ones with conservative approach.
     * Reduces merge window to 5 seconds to match Digital Wellbeing's stricter boundaries.
     */
    private fun deduplicateSessions(sessions: List<UsageSession>): List<UsageSession> {
        if (sessions.isEmpty()) return emptyList()
        
        val sortedSessions = sessions.sortedBy { it.startTime }
        val deduplicatedSessions = mutableListOf<UsageSession>()
        
        var currentSession = sortedSessions.first()
        
        for (i in 1 until sortedSessions.size) {
            val nextSession = sortedSessions[i]
            
            // More conservative merge window: only merge if sessions overlap or are within 5 seconds
            if (nextSession.startTime <= currentSession.endTime + 5000) {
                currentSession = UsageSession(
                    startTime = minOf(currentSession.startTime, nextSession.startTime),
                    endTime = maxOf(currentSession.endTime, nextSession.endTime),
                    packageName = currentSession.packageName
                )
                Log.d(TAG, "Merged overlapping sessions for ${currentSession.packageName}: ${currentSession.duration/1000}s")
            } else {
                deduplicatedSessions.add(currentSession)
                currentSession = nextSession
            }
        }
        
        deduplicatedSessions.add(currentSession)
        return deduplicatedSessions
    }
    
    /**
     * Gets usage data using UsageStats API (similar to Digital Wellbeing approach).
     */
    private fun getStatsBasedUsage(startTime: Long, endTime: Long): Map<String, Long> {
        val usageMap = HashMap<String, Long>()
        
        try {
            Log.d(TAG, "Getting UsageStats from ${Date(startTime)} to ${Date(endTime)}")
            
            // Use INTERVAL_BEST for most accurate data
            val usageStats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                startTime,
                endTime
            )
            
            usageStats.forEach { stats ->
                if (isValidUserApp(stats.packageName)) {
                    val foregroundTime = stats.totalTimeInForeground
                    if (foregroundTime > 0) {
                        usageMap[stats.packageName] = foregroundTime
                        Log.d(TAG, "Stats: ${stats.packageName} = ${foregroundTime/1000}s")
                    }
                }
            }
            
            Log.d(TAG, "UsageStats returned ${usageMap.size} apps")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting stats-based usage", e)
        }
        
        return usageMap
    }
    
    /**
     * Checks if the package is a valid user app (not system app or background service).
     * Updated filtering to better match Digital Wellbeing's app selection.
     */
    private fun isValidUserApp(packageName: String): Boolean {
        try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            
            // More aggressive filtering to match Digital Wellbeing
            return when {
                // Skip known background service packages
                packageName.contains(".service") -> false
                packageName.contains(".provider") -> false
                packageName.endsWith(":background") -> false
                packageName.endsWith(":remote") -> false
                packageName.contains(":") -> false // Skip all process variants
                
                // Skip most system processes
                packageName.startsWith("com.android.") && !isUserFacingSystemApp(packageName) -> false
                packageName.startsWith("android.") -> false
                packageName.startsWith("com.google.android.") && !isUserFacingSystemApp(packageName) -> false
                
                // Check if it has a launcher intent (main indicator of user app)
                packageManager.getLaunchIntentForPackage(packageName) != null -> true
                
                // For system apps without launcher, check if they're commonly used user apps
                (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0 -> {
                    isUserFacingSystemApp(packageName)
                }
                
                else -> true // Allow other user apps
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.w(TAG, "Package not found: $packageName")
            return false
        }
    }
    
    /**
     * Checks if a system app is user-facing (should be included in usage stats).
     */
    private fun isUserFacingSystemApp(packageName: String): Boolean {
        return when {
            packageName.contains("chrome") -> true
            packageName.contains("firefox") -> true
            packageName.contains("browser") -> true
            packageName.contains("youtube") -> true
            packageName.contains("gmail") -> true
            packageName.contains("maps") -> true
            packageName.contains("photos") -> true
            packageName.contains("drive") -> true
            packageName.contains("play") && !packageName.contains("services") -> true
            packageName.contains("messenger") -> true
            packageName.contains("whatsapp") -> true
            packageName.contains("instagram") -> true
            packageName.contains("facebook") -> true
            packageName.contains("twitter") -> true
            packageName.contains("tiktok") -> true
            packageName.contains("spotify") -> true
            packageName.contains("netflix") -> true
            packageName.contains("settings") -> true
            packageName.contains("calculator") -> true
            packageName.contains("calendar") -> true
            packageName.contains("clock") -> true
            packageName.contains("camera") -> true
            packageName.contains("gallery") -> true
            packageName.contains("phone") && !packageName.contains("telephony") -> true
            packageName.contains("contacts") -> true
            packageName.contains("messages") && !packageName.contains("messaging") -> true
            packageName.contains("launcher") -> true
            packageName.contains("wellbeing") -> true
            else -> false
        }
    }
    
    /**
     * Gets the display name for a package.
     */
    fun getAppDisplayName(packageName: String): String {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
    
    /**
     * Gets accurate foreground usage time for today, matching Digital Wellbeing's time boundaries.
     * This ensures we use the same day calculation as Digital Wellbeing.
     */
    fun getTodayForegroundUsage(): Map<String, Long> {
        val (startTime, endTime) = getTodayTimeRange()
        
        // Validate time range
        if (endTime <= startTime) {
            Log.e(TAG, "Invalid time range: start=$startTime, end=$endTime")
            return emptyMap()
        }
        
        // Limit to reasonable time range (max 24 hours)
        val maxRange = 24 * 60 * 60 * 1000 // 24 hours in milliseconds
        if (endTime - startTime > maxRange) {
            Log.w(TAG, "Time range too large: ${(endTime - startTime) / 1000}s, limiting to 24 hours")
            val limitedStartTime = endTime - maxRange
            return getAccurateForegroundUsage(limitedStartTime, endTime)
        }
        
        return getAccurateForegroundUsage(startTime, endTime)
    }
    
    /**
     * Gets the time range for "today" usage, matching Digital Wellbeing's calculation.
     * Returns a Pair of (startTime, endTime) for today from midnight to now.
     */
    private fun getTodayTimeRange(): Pair<Long, Long> {
        val calendar = Calendar.getInstance()
        
        // End time is now
        val endTime = calendar.timeInMillis
        
        // Start time is midnight of today
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        
        Log.d(TAG, "Today's time range: ${Date(startTime)} to ${Date(endTime)}")
        return Pair(startTime, endTime)
    }
    
    /**
     * Represents the current state of an app (foreground/background).
     */
    private data class AppState(
        val state: State,
        val timestamp: Long
    ) {
        enum class State {
            FOREGROUND,
            BACKGROUND
        }
    }
    
    /**
     * Represents a usage session for an app.
     */
    private data class UsageSession(
        val startTime: Long,
        val endTime: Long,
        val packageName: String
    ) {
        val duration: Long get() = endTime - startTime
    }
}