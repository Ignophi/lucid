package io.github.ignophi.lucid

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/// Keeps a meditation session running while the screen is off or another app
/// is open: a foreground service (so Android doesn't pause or freeze the app)
/// holding a wake lock (so the phone keeps running the timer, vibrations,
/// tones and sensors). Shows an ongoing notification with the time left.
/// Started and stopped by the meditation screen (lib/home_widget.dart).
class SessionService : Service() {

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_ENDS_AT = "endsAt"
        const val EXTRA_MICROPHONE = "microphone"
        private const val CHANNEL_ID = "session"
        private const val NOTIFICATION_ID = 1001
        private const val MAX_HOLD_MS = 4L * 60 * 60 * 1000 // safety limit: 4 hours
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Lucid"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val endsAt = intent?.getLongExtra(EXTRA_ENDS_AT, 0L) ?: 0L
        val microphone = intent?.getBooleanExtra(EXTRA_MICROPHONE, false) ?: false

        val notification = buildNotification(title, text, endsAt)
        try {
            startInForeground(notification, microphone)
        } catch (e: SecurityException) {
            // E.g. microphone access was taken back: keep the timer going anyway
            startInForeground(notification, false)
        }

        if (wakeLock == null) {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Lucid:session").apply {
                setReferenceCounted(false)
                acquire(MAX_HOLD_MS)
            }
        }
        return START_NOT_STICKY
    }

    private fun startInForeground(notification: Notification, microphone: Boolean) {
        when {
            Build.VERSION.SDK_INT >= 34 -> {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                if (microphone) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                startForeground(NOTIFICATION_ID, notification, type)
            }
            Build.VERSION.SDK_INT >= 30 && microphone ->
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            else -> startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(title: String, text: String, endsAt: Long): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Meditation session",
                    NotificationManager.IMPORTANCE_LOW
                )
                channel.setShowBadge(false)
                manager.createNotificationChannel(channel)
            }
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        // Tapping the notification goes back to the session
        val launch = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
        if (endsAt > System.currentTimeMillis()) {
            // Counts down to the end of the session by itself
            builder.setWhen(endsAt).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= 24) builder.setChronometerCountDown(true)
        }
        return builder.build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The app was swiped away: the session is over
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}
