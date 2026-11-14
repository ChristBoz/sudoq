package com.sudoq.sudoq_usage

import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * KOTLIN BRIDGE: lists the apps the user could choose to monitor.
 *
 * Only apps with a launcher icon are returned (no system services), and
 * suDOq itself is left out.
 */
object AppLister {
    fun list(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()

        for (info in pm.queryIntentActivities(launcher, 0)) {
            val activity = info.activityInfo ?: continue
            val pkg = activity.packageName
            if (pkg == context.packageName || !seen.add(pkg)) continue

            // Android's own category for the app (game, video, social...),
            // or -1 when the app did not declare one.
            val category =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.applicationInfo.category
                } else {
                    -1
                }

            apps.add(
                mapOf(
                    "package" to pkg,
                    "name" to activity.applicationInfo.loadLabel(pm).toString(),
                    "category" to category
                )
            )
        }
        return apps
    }
}
