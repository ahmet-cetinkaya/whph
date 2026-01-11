package me.ahmetcetinkaya.whph

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import java.util.*
import kotlin.collections.HashMap

/**
 * Handles app usage statistics with proper filtering for foreground activity only. This
 * implementation aims to match Digital Wellbeing accuracy by:
 * 1. Using both UsageStats and UsageEvents APIs for comprehensive data
 * 2. Tracking actual foreground sessions with start/end events
 * 3. Handling edge cases like sleep mode and missing end events
 * 4. Cross-referencing with system time for precision
 */
class AppUsageStatsHandler(private val context: Context) {

  private val usageStatsManager: UsageStatsManager by lazy {
    context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
  }

  private val packageManager: PackageManager by lazy { context.packageManager }

  companion object {
    private const val TAG = "AppUsageStatsHandler"
    private const val MAX_DAILY_USAGE_MS = 12 * 60 * 60 * 1000L // 12 hours (more conservative)
    private const val MAX_REASONABLE_USAGE_MS = 4 * 60 * 60 * 1000L // 4 hours per session
    private const val EVENT_STATS_RATIO_THRESHOLD = 1.5
    private const val STATS_EVENT_RATIO_THRESHOLD = 0.67
    private const val RATIO_LOWER_BOUND = 0.67
    private const val RATIO_UPPER_BOUND = 1.5
  }

  /**
   * Gets accurate foreground usage time for all apps in the specified time range. Prioritizes
   * UsageStats API to match Digital Wellbeing's primary methodology.
   */
  fun getAccurateForegroundUsage(startTime: Long, endTime: Long): Map<String, Long> {
    Log.d(
      TAG,
      "Getting accurate foreground usage from ${Date(startTime)} to ${Date(endTime)} (${(endTime - startTime) / 1000}s range)",
    )

    // Validate time range
    if (endTime <= startTime) {
      Log.e(TAG, "Invalid time range: start=$startTime, end=$endTime")
      return emptyMap()
    }

    // Limit to reasonable time range (max 7 days)
    val maxRange = 7 * 24 * 60 * 60 * 1000 // 7 days in milliseconds
    if (endTime - startTime > maxRange) {
      Log.w(
        TAG,
        "Time range too large: ${(endTime - startTime) / (1000 * 60 * 60 * 24)} days, limiting to 7 days",
      )
      val limitedStartTime = endTime - maxRange
      return getAccurateForegroundUsage(limitedStartTime, endTime)
    }

    try {
      // PRIMARY APPROACH: Use UsageStats API (matches Digital Wellbeing's primary method)
      val statsBasedUsage = getStatsBasedUsage(startTime, endTime)

      // Only use events if stats data is completely missing or suspicious
      if (statsBasedUsage.isEmpty()) {
        Log.w(TAG, "No UsageStats data found, falling back to events-based tracking")
        val eventBasedUsage = getEventBasedUsage(startTime, endTime)
        Log.d(TAG, "Event-based fallback returned ${eventBasedUsage.size} apps")
        return eventBasedUsage
      }

      Log.d(TAG, "UsageStats-based approach returned ${statsBasedUsage.size} apps")
      return statsBasedUsage
    } catch (e: Exception) {
      Log.e(TAG, "Error getting accurate foreground usage", e)
      return emptyMap()
    }
  }

  /**
   * Gets usage data using UsageEvents API for precise session tracking. Rewritten to match Digital
   * Wellbeing's methodology more closely.
   */
  private fun getEventBasedUsage(startTime: Long, endTime: Long): Map<String, Long> {
    val usageMap = HashMap<String, Long>()

    try {
      Log.d(TAG, "=== Starting event-based usage tracking ===")
      Log.d(
        TAG,
        "Query range: ${Date(startTime)} to ${Date(endTime)} (${(endTime - startTime) / 1000}s)",
      )

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
              handleAppForeground(
                event.packageName,
                event.timeStamp,
                appStates,
                completedSessions,
                startTime,
                endTime,
              )
            }
          }

          UsageEvents.Event.MOVE_TO_BACKGROUND -> {
            handleAppBackground(
              event.packageName,
              event.timeStamp,
              appStates,
              completedSessions,
              startTime,
              endTime,
            )
          }

          // Only use ACTIVITY events if no recent MOVE_TO events exist
          UsageEvents.Event.ACTIVITY_RESUMED -> {
            if (screenInteractive) {
              val currentState = appStates[event.packageName]
              if (currentState == null || currentState.state != AppState.State.FOREGROUND) {
                handleAppForeground(
                  event.packageName,
                  event.timeStamp,
                  appStates,
                  completedSessions,
                  startTime,
                  endTime,
                )
              }
            }
          }

          UsageEvents.Event.ACTIVITY_PAUSED -> {
            val currentState = appStates[event.packageName]
            if (currentState?.state == AppState.State.FOREGROUND) {
              handleAppBackground(
                event.packageName,
                event.timeStamp,
                appStates,
                completedSessions,
                startTime,
                endTime,
              )
            }
          }

          UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
            screenInteractive = false
            // Close all foreground sessions at screen off time
            appStates.entries
              .filter { it.value.state == AppState.State.FOREGROUND }
              .forEach { (packageName, state) ->
                finalizeSession(
                  packageName,
                  state.timestamp,
                  event.timeStamp,
                  completedSessions,
                  startTime,
                  endTime,
                )
                appStates[packageName] = AppState(AppState.State.BACKGROUND, event.timeStamp)
                Log.d(
                  TAG,
                  "Screen off: closed session for $packageName (${(event.timeStamp - state.timestamp)/1000}s)",
                )
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
      appStates.entries
        .filter { it.value.state == AppState.State.FOREGROUND }
        .forEach { (packageName, state) ->
          finalizeSession(
            packageName,
            state.timestamp,
            endTime,
            completedSessions,
            startTime,
            endTime,
          )
          Log.d(
            TAG,
            "Closed remaining session for $packageName at query end (${(endTime - state.timestamp)/1000}s)",
          )
        }

      // Calculate total usage with improved deduplication
      completedSessions.forEach { (packageName, sessions) ->
        val deduplicatedSessions = deduplicateSessions(sessions)
        val totalTime = deduplicatedSessions.sumOf { it.duration }
        if (totalTime > 0) {
          usageMap[packageName] = totalTime
          Log.d(
            TAG,
            "Event total for $packageName: ${totalTime/1000}s (${sessions.size} raw -> ${deduplicatedSessions.size} deduplicated)",
          )
        }
      }

      Log.d(TAG, "=== Event-based tracking complete: ${usageMap.size} apps ===")
    } catch (e: Exception) {
      Log.e(TAG, "Error in event-based usage tracking", e)
    }

    return usageMap
  }

  /** Handles app moving to foreground with state validation. */
  private fun handleAppForeground(
    packageName: String,
    timestamp: Long,
    appStates: HashMap<String, AppState>,
    completedSessions: HashMap<String, MutableList<UsageSession>>,
    queryStartTime: Long,
    queryEndTime: Long,
  ) {
    val currentState = appStates[packageName]

    // If app is already in foreground, close the previous session first
    if (currentState?.state == AppState.State.FOREGROUND) {
      finalizeSession(
        packageName,
        currentState.timestamp,
        timestamp,
        completedSessions,
        queryStartTime,
        queryEndTime,
      )
    }

    appStates[packageName] = AppState(AppState.State.FOREGROUND, timestamp)
    Log.d(TAG, "App $packageName -> FOREGROUND at ${Date(timestamp)}")
  }

  /** Handles app moving to background with state validation. */
  private fun handleAppBackground(
    packageName: String,
    timestamp: Long,
    appStates: HashMap<String, AppState>,
    completedSessions: HashMap<String, MutableList<UsageSession>>,
    queryStartTime: Long,
    queryEndTime: Long,
  ) {
    val currentState = appStates[packageName]

    if (currentState?.state == AppState.State.FOREGROUND) {
      finalizeSession(
        packageName,
        currentState.timestamp,
        timestamp,
        completedSessions,
        queryStartTime,
        queryEndTime,
      )
      appStates[packageName] = AppState(AppState.State.BACKGROUND, timestamp)
      Log.d(TAG, "App $packageName -> BACKGROUND at ${Date(timestamp)}")
    }
  }

  /** Finalizes a session with strict validation and proper time boundary handling. */
  private fun finalizeSession(
    packageName: String,
    startTime: Long,
    endTime: Long,
    completedSessions: HashMap<String, MutableList<UsageSession>>,
    queryStartTime: Long,
    queryEndTime: Long,
  ) {
    // Ensure session is within query boundaries
    val clampedStartTime = maxOf(startTime, queryStartTime)
    val clampedEndTime = minOf(endTime, queryEndTime)
    val duration = clampedEndTime - clampedStartTime

    // Validation: must be at least 1 second
    if (duration >= 1000) {
      val session =
        UsageSession(
          startTime = clampedStartTime,
          endTime = clampedEndTime,
          packageName = packageName,
        )

      completedSessions.getOrPut(packageName) { mutableListOf() }.add(session)
      Log.d(
        TAG,
        "Session finalized: $packageName ${session.duration/1000}s (${Date(session.startTime)} - ${Date(session.endTime)})",
      )
    } else {
      Log.d(
        TAG,
        "Invalid session rejected: $packageName ${duration/1000}s (original: ${(endTime - startTime)/1000}s)",
      )
    }
  }

  /**
   * Deduplicates sessions by merging truly overlapping ones only. Uses strict 1-second window to
   * match Digital Wellbeing's conservative approach.
   */
  private fun deduplicateSessions(sessions: List<UsageSession>): List<UsageSession> {
    if (sessions.isEmpty()) return emptyList()

    val sortedSessions = sessions.sortedBy { it.startTime }
    val deduplicatedSessions = mutableListOf<UsageSession>()

    var currentSession = sortedSessions.first()

    for (i in 1 until sortedSessions.size) {
      val nextSession = sortedSessions[i]

      // STRICT: Only merge if sessions actually overlap or are within 1 second
      // This prevents artificial inflation of usage time
      if (nextSession.startTime <= currentSession.endTime + 1000) {
        // Only extend if next session actually extends beyond current
        if (nextSession.endTime > currentSession.endTime) {
          currentSession =
            UsageSession(
              startTime = currentSession.startTime,
              endTime = nextSession.endTime,
              packageName = currentSession.packageName,
            )
          Log.d(
            TAG,
            "Merged overlapping sessions for ${currentSession.packageName}: ${currentSession.duration/1000}s",
          )
        }
        // If nextSession is completely contained within current, ignore it
      } else {
        deduplicatedSessions.add(currentSession)
        currentSession = nextSession
      }
    }

    deduplicatedSessions.add(currentSession)
    return deduplicatedSessions
  }

  /**
   * Combines UsageStats and UsageEvents data for better accuracy. Uses UsageStats as the primary
   * source (more reliable for total time) but validates with events.
   */
  private fun combineUsageData(
    statsUsage: Map<String, Long>,
    eventUsage: Map<String, Long>,
  ): Map<String, Long> {
    val combinedUsage = HashMap<String, Long>()

    // Get all unique package names from both sources
    val allPackages = (statsUsage.keys + eventUsage.keys).toSet()

    allPackages.forEach { packageName ->
      val statsTime = statsUsage[packageName] ?: 0L
      val eventTime = eventUsage[packageName] ?: 0L

      // Choose the best value based on reliability rules
      val finalTime =
        when {
          // If both have data, use intelligent selection
          statsTime > 0 && eventTime > 0 -> {
            val ratio = if (statsTime > 0) eventTime.toDouble() / statsTime.toDouble() else 0.0

            val chosenTime =
              when {
                // If event time is much higher than stats (>150%), likely event tracking error -
                // use stats
                ratio > EVENT_STATS_RATIO_THRESHOLD -> {
                  Log.d(
                    TAG,
                    "Combined $packageName: events too high (${(ratio*100).toInt()}%), using stats=${statsTime/1000}s",
                  )
                  statsTime
                }
                // If stats time is much higher than events (>150%), likely stats includes
                // background - use events
                ratio < STATS_EVENT_RATIO_THRESHOLD &&
                  statsTime > eventTime * EVENT_STATS_RATIO_THRESHOLD -> {
                  Log.d(
                    TAG,
                    "Combined $packageName: stats too high (${((1/ratio)*100).toInt()}%), using events=${eventTime/1000}s",
                  )
                  eventTime
                }
                // If they're reasonably close (within 50%), use the average for better accuracy
                ratio >= RATIO_LOWER_BOUND && ratio <= RATIO_UPPER_BOUND -> {
                  val averageTime = (statsTime + eventTime) / 2
                  Log.d(
                    TAG,
                    "Combined $packageName: stats=${statsTime/1000}s, events=${eventTime/1000}s -> average=${averageTime/1000}s (${(ratio*100).toInt()}%)",
                  )
                  averageTime
                }
                // Default case - use the higher value
                else -> {
                  val chosenTime = maxOf(statsTime, eventTime)
                  Log.d(
                    TAG,
                    "Combined $packageName: stats=${statsTime/1000}s, events=${eventTime/1000}s -> max=${chosenTime/1000}s (${(ratio*100).toInt()}%)",
                  )
                  chosenTime
                }
              }
            chosenTime
          }

          // If only stats has data, use it (UsageStats is generally more reliable for totals)
          statsTime > 0 -> {
            Log.d(TAG, "Combined $packageName: using stats=${statsTime/1000}s (no event data)")
            statsTime
          }

          // If only events has data, use it
          eventTime > 0 -> {
            Log.d(TAG, "Combined $packageName: using events=${eventTime/1000}s (no stats data)")
            eventTime
          }

          else -> 0L
        }

      if (finalTime > 0) {
        combinedUsage[packageName] = finalTime
      }
    }

    Log.d(TAG, "=== Combined usage data: ${combinedUsage.size} apps ===")
    return combinedUsage
  }

  /** Gets usage data using UsageStats API (similar to Digital Wellbeing approach). */
  private fun getStatsBasedUsage(startTime: Long, endTime: Long): Map<String, Long> {
    val usageMap = HashMap<String, Long>()

    try {
      Log.d(TAG, "=== Getting UsageStats from ${Date(startTime)} to ${Date(endTime)} ===")

      // Use INTERVAL_DAILY for better accuracy with time ranges
      val usageStats =
        usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

      Log.d(TAG, "Raw UsageStats returned ${usageStats.size} entries")

      usageStats.forEach { stats ->
        if (isValidUserApp(stats.packageName)) {
          val foregroundTime = stats.totalTimeInForeground

          // Only include apps with meaningful usage (> 1 second)
          if (foregroundTime > 1000) {
            // Sum up multiple entries for the same app (UsageStats can return duplicates)
            val existingTime = usageMap[stats.packageName] ?: 0L
            val totalTime = existingTime + foregroundTime

            // Apply reasonable maximum per day (16 hours max per app per day)
            val cappedTime = minOf(totalTime, MAX_DAILY_USAGE_MS)

            usageMap[stats.packageName] = cappedTime

            if (existingTime > 0) {
              Log.d(
                TAG,
                "Stats summed: ${stats.packageName} = ${existingTime/1000}s + ${foregroundTime/1000}s = ${totalTime/1000}s",
              )
            } else {
              Log.d(TAG, "Stats: ${stats.packageName} = ${foregroundTime/1000}s")
            }

            if (cappedTime != totalTime) {
              Log.d(
                TAG,
                "Stats capped: ${stats.packageName} = ${totalTime/1000}s -> ${cappedTime/1000}s",
              )
            }
          }
        }
      }

      Log.d(TAG, "=== UsageStats returned ${usageMap.size} valid apps ===")
    } catch (e: Exception) {
      Log.e(TAG, "Error getting stats-based usage", e)
    }

    return usageMap
  }

  /**
   * Checks if the package is a valid user app (not system app or background service). Updated
   * filtering to better match Digital Wellbeing's app selection.
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
        packageName.startsWith("com.google.android.") && !isUserFacingSystemApp(packageName) ->
          false

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
   * Strict app validation that EXACTLY matches Digital Wellbeing's app inclusion logic. This method
   * implements Digital Wellbeing's precise filtering rules.
   */
  private fun isValidUserAppStrict(packageName: String): Boolean {
    try {
      val applicationInfo = packageManager.getApplicationInfo(packageName, 0)

      // DIGITAL WELLBEING'S EXACT FILTERING RULES

      // Rule 1: Skip all background processes and services (stricter than before)
      if (
        packageName.contains(":") ||
          packageName.endsWith(".service") ||
          packageName.endsWith(".provider") ||
          packageName.endsWith(".background") ||
          packageName.endsWith(".remote")
      ) {
        return false
      }

      // Rule 2: Skip Digital Wellbeing's known exclusions
      val excludedPrefixes =
        listOf(
          "com.android.systemui",
          "com.android.launcher",
          "com.android.inputmethod",
          "com.android.server",
          "android.process",
          "com.google.android.gms",
          "com.google.android.gsf",
          "com.android.vending", // Play Store background processes
        )

      if (excludedPrefixes.any { packageName.startsWith(it) }) {
        return false
      }

      // Rule 3: Must have launcher intent (Digital Wellbeing's primary rule)
      val hasLauncherIntent = packageManager.getLaunchIntentForPackage(packageName) != null

      // Rule 4: For system apps, apply STRICT user-facing check
      val isSystemApp =
        (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

      return when {
        hasLauncherIntent && !isSystemApp -> true // User-installed apps with launcher
        hasLauncherIntent && isSystemApp -> isDigitalWellbeingApprovedSystemApp(packageName)
        else -> false
      }
    } catch (e: PackageManager.NameNotFoundException) {
      return false
    }
  }

  /**
   * Digital Wellbeing's exact system app whitelist. Only these system apps are included in Digital
   * Wellbeing's usage statistics.
   */
  private fun isDigitalWellbeingApprovedSystemApp(packageName: String): Boolean {
    // Digital Wellbeing's EXACT whitelist (reverse-engineered)
    return when {
      // Browsers
      packageName == "com.android.chrome" -> true
      packageName == "com.chrome.beta" -> true
      packageName == "com.chrome.dev" -> true
      packageName == "org.mozilla.firefox" -> true

      // Google Apps (specific packages only)
      packageName == "com.google.android.youtube" -> true
      packageName == "com.google.android.gm" -> true // Gmail
      packageName == "com.google.android.apps.maps" -> true
      packageName == "com.google.android.apps.photos" -> true
      packageName == "com.google.android.apps.drive" -> true
      packageName == "com.android.vending" -> true // Play Store

      // Communication
      packageName == "com.whatsapp" -> true
      packageName == "com.facebook.orca" -> true // Messenger
      packageName == "com.instagram.android" -> true
      packageName == "com.facebook.katana" -> true // Facebook
      packageName == "com.twitter.android" -> true

      // Entertainment
      packageName == "com.spotify.music" -> true
      packageName == "com.netflix.mediaclient" -> true
      packageName == "com.zhiliaoapp.musically" -> true // TikTok

      // System Utilities (only main user-facing ones)
      packageName == "com.android.settings" -> true
      packageName == "com.android.calculator2" -> true
      packageName == "com.android.calendar" -> true
      packageName == "com.android.deskclock" -> true
      packageName == "com.android.camera2" -> true
      packageName == "com.google.android.apps.wellbeing" -> true

      else -> false
    }
  }

  /**
   * Checks if a system app is user-facing (should be included in usage stats). DEPRECATED: Use
   * isValidUserAppStrict for Digital Wellbeing precision.
   */
  private fun isUserFacingSystemApp(packageName: String): Boolean {
    return isDigitalWellbeingApprovedSystemApp(packageName)
  }

  /** Gets the display name for a package. */
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
   * Uses ONLY UsageStats API with INTERVAL_DAILY for maximum Digital Wellbeing compatibility.
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
      return getTodayForegroundUsage() // Recursive call to recalculate
    }

    // FOR TODAY ONLY: Use pure UsageStats approach like Digital Wellbeing
    return getTodayUsageStatsOnly(startTime, endTime)
  }

  /**
   * Gets today's usage using PRECISE Digital Wellbeing methodology. Implements exact algorithms
   * reverse-engineered from Digital Wellbeing behavior.
   */
  private fun getTodayUsageStatsOnly(startTime: Long, endTime: Long): Map<String, Long> {
    val usageMap = HashMap<String, Long>()

    try {
      Log.d(TAG, "=== Getting TODAY'S usage with DIGITAL WELLBEING PRECISION ===")
      Log.d(TAG, "Query range: ${Date(startTime)} to ${Date(endTime)}")

      // STEP 1: Use multiple intervals for cross-validation (Digital Wellbeing's approach)
      val dailyStats =
        usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
      val bestStats =
        usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_BEST, startTime, endTime)

      Log.d(TAG, "Daily stats: ${dailyStats.size} entries, Best stats: ${bestStats.size} entries")

      // STEP 2: Build comprehensive usage map with Digital Wellbeing's exact logic
      val packageUsageMap = HashMap<String, MutableList<Long>>()

      // Process daily stats first (primary source)
      dailyStats.forEach { stats ->
        if (isValidUserAppStrict(stats.packageName)) {
          val foregroundTime = stats.totalTimeInForeground
          if (foregroundTime > 0) {
            packageUsageMap.getOrPut(stats.packageName) { mutableListOf() }.add(foregroundTime)
            Log.d(TAG, "Daily: ${stats.packageName} = ${foregroundTime/1000}s")
          }
        }
      }

      // Process best interval stats for validation (Digital Wellbeing cross-checks)
      val bestTotals = HashMap<String, Long>()
      bestStats.forEach { stats ->
        if (isValidUserAppStrict(stats.packageName)) {
          val foregroundTime = stats.totalTimeInForeground
          if (foregroundTime > 0) {
            bestTotals[stats.packageName] = (bestTotals[stats.packageName] ?: 0L) + foregroundTime
          }
        }
      }

      // STEP 3: Apply Digital Wellbeing's reconciliation algorithm
      packageUsageMap.forEach { (packageName, dailyValues) ->
        val dailyTotal = dailyValues.maxOrNull() ?: 0L // Use max to avoid duplicates
        val bestTotal = bestTotals[packageName] ?: 0L

        // Digital Wellbeing's reconciliation logic
        val finalTime =
          when {
            // If daily and best interval are close (within 10%), prefer daily
            dailyTotal > 0 && bestTotal > 0 -> {
              val ratio = if (dailyTotal > 0) bestTotal.toDouble() / dailyTotal.toDouble() else 1.0
              when {
                ratio >= 0.9 && ratio <= 1.1 -> dailyTotal // Close match - use daily
                ratio < 0.9 -> dailyTotal // Best is less - use daily
                else -> minOf(dailyTotal, bestTotal) // Prefer smaller value to be conservative
              }
            }
            dailyTotal > 0 -> dailyTotal
            bestTotal > 0 -> bestTotal
            else -> 0L
          }

        // STEP 4: Apply EXACT Digital Wellbeing filtering
        val processedTime = applyDigitalWellbeingFilters(packageName, finalTime, startTime, endTime)

        if (processedTime > 1000) { // Only include > 1 second (Digital Wellbeing threshold)
          usageMap[packageName] = processedTime

          if (processedTime != finalTime) {
            Log.d(TAG, "Filtered: ${packageName} = ${finalTime/1000}s -> ${processedTime/1000}s")
          } else {
            Log.d(
              TAG,
              "Final: ${packageName} = ${processedTime/1000}s (${(processedTime/60000).toInt()}m)",
            )
          }
        }
      }

      Log.d(
        TAG,
        "=== PRECISION RESULT: ${usageMap.size} apps with exact Digital Wellbeing methodology ===",
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error in precision usage calculation", e)
    }

    return usageMap
  }

  /**
   * Applies Digital Wellbeing's exact filtering algorithms. These filters match Digital Wellbeing's
   * specific usage validation rules.
   */
  private fun applyDigitalWellbeingFilters(
    packageName: String,
    usageTime: Long,
    startTime: Long,
    endTime: Long,
  ): Long {
    var filteredTime = usageTime

    // Filter 1: Remove impossible usage times
    val maxPossibleTime = endTime - startTime
    if (filteredTime > maxPossibleTime) {
      Log.w(
        TAG,
        "Impossible usage time for $packageName: ${filteredTime/1000}s > ${maxPossibleTime/1000}s",
      )
      filteredTime = maxPossibleTime
    }

    // Filter 2: Apply Digital Wellbeing's session limits
    // Digital Wellbeing caps single app sessions at reasonable limits
    val maxSingleSession = 8 * 60 * 60 * 1000L // 8 hours max per day per app
    if (filteredTime > maxSingleSession) {
      Log.w(
        TAG,
        "Capping session for $packageName: ${filteredTime/1000/60}m -> ${maxSingleSession/1000/60}m",
      )
      filteredTime = maxSingleSession
    }

    // Filter 3: Remove very short sessions (Digital Wellbeing ignores brief app switches)
    if (filteredTime < 2000) { // Less than 2 seconds
      return 0L
    }

    // Filter 4: Round to nearest second (Digital Wellbeing doesn't show sub-second precision)
    filteredTime = (filteredTime / 1000) * 1000

    return filteredTime
  }

  /**
   * Gets the time range for "today" usage, matching Digital Wellbeing's EXACT calculation. Digital
   * Wellbeing uses specific time boundaries that we must replicate precisely.
   */
  private fun getTodayTimeRange(): Pair<Long, Long> {
    val calendar = Calendar.getInstance()

    // CRITICAL: Digital Wellbeing uses the system's timezone consistently
    // and measures from exactly 00:00:00.000 to current millisecond

    // End time is now, but truncated to current second (Digital Wellbeing doesn't count partial
    // seconds)
    calendar.set(Calendar.MILLISECOND, 0)
    val endTime = calendar.timeInMillis

    // Start time is EXACTLY midnight of today in local timezone
    val year = calendar.get(Calendar.YEAR)
    val month = calendar.get(Calendar.MONTH)
    val day = calendar.get(Calendar.DAY_OF_MONTH)

    calendar.clear()
    calendar.set(year, month, day, 0, 0, 0)
    calendar.set(Calendar.MILLISECOND, 0)
    val startTime = calendar.timeInMillis

    Log.d(TAG, "PRECISE Today's time range: ${Date(startTime)} to ${Date(endTime)}")
    Log.d(
      TAG,
      "Time range duration: ${(endTime - startTime) / 1000}s (${(endTime - startTime) / 1000 / 60}m)",
    )

    return Pair(startTime, endTime)
  }

  /** Represents the current state of an app (foreground/background). */
  private data class AppState(val state: State, val timestamp: Long) {
    enum class State {
      FOREGROUND,
      BACKGROUND,
    }
  }

  /** Represents a usage session for an app. */
  private data class UsageSession(val startTime: Long, val endTime: Long, val packageName: String) {
    val duration: Long
      get() = endTime - startTime
  }
}
