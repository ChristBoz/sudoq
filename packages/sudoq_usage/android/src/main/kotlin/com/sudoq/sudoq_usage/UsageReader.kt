package com.sudoq.sudoq_usage

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings

/**
 * KOTLIN BRIDGE: everything that touches Android's usage statistics.
 *
 *  - [hasAccess]    is "Usage access" switched on for suDOq?
 *  - [openSettings] opens the screen where the user switches it on
 *  - [read]         foreground time per app between two moments
 */
object UsageReader {
    // Event type numbers from android.app.usage.UsageEvents.Event.
    private const val ACTIVITY_RESUMED = 1 // app came to the front
    private const val ACTIVITY_PAUSED = 2 // app left the front
    private const val SCREEN_NON_INTERACTIVE = 16 // screen turned off
    private const val DEVICE_SHUTDOWN = 26

    fun hasAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }
        if (mode == AppOpsManager.MODE_DEFAULT) {
            return context.checkCallingOrSelfPermission(
                android.Manifest.permission.PACKAGE_USAGE_STATS
            ) == PackageManager.PERMISSION_GRANTED
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun openSettings(context: Context) {
        val direct =
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                .setData(Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            // Some phones jump straight to suDOq's own switch.
            context.startActivity(direct)
        } catch (e: Exception) {
            // Others only accept the general list of apps.
            context.startActivity(
                Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    /**
     * Adds up how long each app was in the foreground between [start] and
     * [end] (both in milliseconds since 1970).
     *
     * Returns:
     *  - "eventCount": how many usage events Android returned. 0 means
     *    Android had no data for this period, which is different from
     *    "every app was used for 0 minutes".
     *  - "usageMs": package name -> milliseconds in the foreground.
     */
    fun read(
        context: Context,
        start: Long,
        end: Long
    ): Map<String, Any> {
        val manager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()

        val openedAt = HashMap<String, Long>() // apps currently in front
        val seen = HashSet<String>() // apps that had any event
        val totals = HashMap<String, Long>()
        var eventCount = 0

        fun add(
            pkg: String,
            from: Long,
            to: Long
        ) {
            if (to > from) totals[pkg] = (totals[pkg] ?: 0L) + (to - from)
        }

        fun closeAll(at: Long) {
            for ((pkg, opened) in openedAt) add(pkg, opened, at)
            openedAt.clear()
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            eventCount++
            val time = event.timeStamp

            when (event.eventType) {
                ACTIVITY_RESUMED -> {
                    val pkg = event.packageName ?: continue
                    seen.add(pkg)
                    if (!openedAt.containsKey(pkg)) openedAt[pkg] = time
                }

                ACTIVITY_PAUSED -> {
                    val pkg = event.packageName ?: continue
                    val opened = openedAt.remove(pkg)
                    if (opened != null) {
                        add(pkg, opened, time)
                    } else if (seen.add(pkg)) {
                        // First thing we see is the app leaving the front,
                        // so it was already open when the period started.
                        add(pkg, start, time)
                    }
                }

                // Nothing is "in the foreground" while the screen is off.
                SCREEN_NON_INTERACTIVE, DEVICE_SHUTDOWN -> closeAll(time)
            }
        }

        // Apps still in front when the period ends.
        closeAll(end)

        return mapOf("eventCount" to eventCount, "usageMs" to totals)
    }
}
