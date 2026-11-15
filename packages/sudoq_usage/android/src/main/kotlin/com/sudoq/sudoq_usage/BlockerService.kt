package com.sudoq.sudoq_usage

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.provider.Settings
import java.util.Calendar

/**
 * KOTLIN BRIDGE: the blocker.
 *
 * A small service that stays running in the background. Once a second it
 * looks at which app is on screen. If that app is monitored and its daily
 * goal is reached, it brings suDOq to the front, where the Sudoku puzzle
 * is shown. The app stays usable only after the puzzle is solved, and
 * only until the user leaves it.
 *
 * Android requires such a service to show a permanent notification.
 * Bringing suDOq to the front needs the "Display over other apps"
 * permission.
 */
class BlockerService : Service() {
    private lateinit var thread: HandlerThread
    private lateinit var handler: Handler

    /** The app currently on screen, as far as the usage events tell. */
    private var foreground: String? = null
    private var lastEventTime = 0L

    /** Result of the last "is the goal reached?" check, and for which app. */
    private var checkedPackage: String? = null
    private var checkedAt = 0L
    private var goalReached = false

    private var lastGateAt = 0L

    private val tick =
        object : Runnable {
            override fun run() {
                try {
                    poll()
                } catch (e: Exception) {
                    // A failed look is simply retried a second later.
                }
                handler.postDelayed(this, POLL_MS)
            }
        }

    override fun onCreate() {
        super.onCreate()
        showPermanentNotification()
        thread = HandlerThread("sudoq-blocker")
        thread.start()
        handler = Handler(thread.looper)
        handler.post(tick)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int = START_STICKY // Android restarts the service if it is killed

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        thread.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** One look at the screen. */
    private fun poll() {
        val config = BlockerConfig.load(this)
        if (!config.enabled || config.apps.isEmpty()) {
            stopSelf()
            return
        }
        if (!UsageReader.hasAccess(this)) return

        val now = System.currentTimeMillis()
        updateForeground(now)
        val current = foreground ?: return

        // suDOq itself is never blocked, and showing the puzzle must not
        // cancel the pass of the app the puzzle is for.
        if (current == packageName) return

        // Leaving the app ends its pass: opening it again asks again.
        val passed = BlockerState.passedPackage
        if (passed != null && passed != current) BlockerState.passedPackage = null

        val rule = config.apps[current] ?: return
        if (BlockerState.passedPackage == current) return

        // Adding up usage is not free, so it is redone only when the app
        // on screen changes, or every few seconds while it stays open.
        if (checkedPackage != current || now - checkedAt > RECHECK_MS) {
            val usedMinutes = minutesToday(current, config.historyStartMs, now)
            goalReached = usedMinutes + rule.extraMinutes >= rule.limitMinutes
            checkedPackage = current
            checkedAt = now
        }

        if (goalReached && now - lastGateAt > GATE_GAP_MS && Settings.canDrawOverlays(this)) {
            lastGateAt = now
            BlockerState.pendingGate = current
            bringSudoqToFront()
        }
    }

    /** Reads the newest usage events to learn which app is on screen. */
    private fun updateForeground(now: Long) {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        // Look back a little further than the last look, because Android
        // can deliver events slightly late; older ones are skipped below.
        val from = if (lastEventTime == 0L) now - FIRST_LOOKBACK_MS else lastEventTime - 2_000
        val events = manager.queryEvents(from, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.timeStamp <= lastEventTime) continue
            lastEventTime = event.timeStamp
            if (event.eventType == ACTIVITY_RESUMED) foreground = event.packageName
        }
    }

    private fun minutesToday(
        pkg: String,
        historyStartMs: Long,
        now: Long
    ): Int {
        val midnight =
            Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        val start = maxOf(midnight, historyStartMs)
        val usage = UsageReader.read(this, start, now)["usageMs"] as? Map<*, *>
        val ms = (usage?.get(pkg) as? Long) ?: 0L
        return (ms / 60_000L).toInt()
    }

    private fun bringSudoqToFront() {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launch)
    }

    private fun showPermanentNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Limit watcher",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "Shown while suDOq watches for apps that reached their daily goal"
                }
            )
        }
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
        val notification =
            builder
                .setContentTitle("suDOq is watching your daily goals")
                .setContentText("A Sudoku appears when you open an app past its goal.")
                .setSmallIcon(applicationInfo.icon)
                .setOngoing(true)
                .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val ACTIVITY_RESUMED = 1
        private const val POLL_MS = 1_000L
        private const val RECHECK_MS = 15_000L
        private const val GATE_GAP_MS = 3_000L
        private const val FIRST_LOOKBACK_MS = 60_000L
        private const val CHANNEL_ID = "sudoq_blocker"
        private const val NOTIFICATION_ID = 4201

        /** Starts or stops the service to match the saved configuration. */
        fun sync(context: Context) {
            val config = BlockerConfig.load(context)
            val intent = Intent(context, BlockerService::class.java)
            try {
                if (config.enabled && config.apps.isNotEmpty()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } else {
                    context.stopService(intent)
                }
            } catch (e: Exception) {
                // Android refused to start it now; the next sync retries.
            }
        }
    }
}

/** Restarts the blocker after the phone is switched on. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) BlockerService.sync(context)
    }
}
