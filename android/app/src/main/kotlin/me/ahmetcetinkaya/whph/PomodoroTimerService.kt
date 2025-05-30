package me.ahmetcetinkaya.whph

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class PomodoroTimerService : Service() {
    
    private val binder = PomodoroTimerBinder()
    private var handler: Handler? = null
    private var timerRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
    private var remainingTimeSeconds = 0
    private var isRunning = false
    
    companion object {
        private const val TAG = "PomodoroTimerService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "pomodoro_timer_channel"
        private const val CHANNEL_NAME = "Pomodoro Timer"
        
        const val ACTION_START_TIMER = "START_TIMER"
        const val ACTION_STOP_TIMER = "STOP_TIMER"
        
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
    }
    
    inner class PomodoroTimerBinder : Binder() {
        fun getService(): PomodoroTimerService = this@PomodoroTimerService
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
        acquireWakeLock()
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_TIMER -> {
                val duration = intent.getIntExtra(EXTRA_DURATION_SECONDS, 1500) // Default 25 minutes
                startTimer(duration)
            }
            ACTION_STOP_TIMER -> {
                stopTimer()
                stopSelf()
            }
        }
        
        return START_STICKY // Restart if killed
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Pomodoro Timer notifications"
                setSound(null, null)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "PomodoroTimer::WakeLock"
        )
        wakeLock?.acquire(60 * 60 * 1000L) // 1 hour max
    }
    
    private fun startTimer(durationSeconds: Int) {
        Log.d(TAG, "Starting timer for $durationSeconds seconds")
        
        remainingTimeSeconds = durationSeconds
        isRunning = true
        
        startForeground(NOTIFICATION_ID, createNotification())
        
        handler = Handler(Looper.getMainLooper())
        timerRunnable = object : Runnable {
            override fun run() {
                if (isRunning && remainingTimeSeconds > 0) {
                    remainingTimeSeconds--
                    updateNotification()
                    handler?.postDelayed(this, 1000)
                } else if (remainingTimeSeconds <= 0) {
                    onTimerComplete()
                }
            }
        }
        
        handler?.post(timerRunnable!!)
    }
    
    private fun stopTimer() {
        Log.d(TAG, "Stopping timer")
        isRunning = false
        handler?.removeCallbacks(timerRunnable!!)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
    
    private fun onTimerComplete() {
        Log.d(TAG, "Timer completed")
        isRunning = false
        
        // Show completion notification
        showCompletionNotification()
        
        // Stop the service
        stopSelf()
    }
    
    private fun createNotification(): Notification {
        val stopIntent = Intent(this, PomodoroTimerService::class.java).apply {
            action = ACTION_STOP_TIMER
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val timeText = formatTime(remainingTimeSeconds)
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pomodoro Timer")
            .setContentText("Time remaining: $timeText")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setSilent(true)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent
            )
            .build()
    }
    
    private fun updateNotification() {
        val notification = createNotification()
        val notificationManager = NotificationManagerCompat.from(this)
        
        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }
    
    private fun showCompletionNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pomodoro Timer")
            .setContentText("Timer completed!")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .build()
            
        val notificationManager = NotificationManagerCompat.from(this)
        try {
            notificationManager.notify(NOTIFICATION_ID + 1, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to show completion notification", e)
        }
    }
    
    private fun formatTime(seconds: Int): String {
        val minutes = seconds / 60
        val remainingSeconds = seconds % 60
        return String.format("%02d:%02d", minutes, remainingSeconds)
    }
    
    fun getRemainingTime(): Int = remainingTimeSeconds
    fun getIsRunning(): Boolean = isRunning
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        
        stopTimer()
        wakeLock?.release()
        wakeLock = null
        handler = null
        timerRunnable = null
    }
}
