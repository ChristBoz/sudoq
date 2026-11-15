package com.sudoq.sudoq_usage

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

/**
 * KOTLIN BRIDGE: the entry point Flutter talks to.
 *
 * It only routes calls. The real work is in [UsageReader], [AppLister]
 * and [BlockerService]. Being a plugin (not code in MainActivity) means
 * it is also available to the background check, which runs without the
 * app being open.
 *
 * Methods on the "sudoq_usage" channel:
 *
 *  Usage
 *  - hasUsageAccess       -> Boolean
 *  - openUsageSettings    -> opens the Android "Usage access" screen
 *  - getInstalledApps     -> List of {package, name, category}
 *  - getUsage(start,end)  -> {eventCount, usageMs: {package: milliseconds}}
 *
 *  Blocker
 *  - hasOverlayPermission -> Boolean ("Display over other apps")
 *  - openOverlaySettings  -> opens the screen where it is granted
 *  - configureBlocker(json) -> saves the rules, starts/stops the service
 *  - takePendingGate      -> package that was just blocked, or null
 *  - passGate(package)    -> puzzle solved: allow the app and reopen it
 *  - goHome               -> puzzle refused: go to the home screen
 */
class SudoqUsagePlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    // Reading usage can take a moment, so it runs off the main thread.
    private val worker = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "sudoq_usage")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            // ---- Usage ----------------------------------------------------
            "hasUsageAccess" -> result.success(UsageReader.hasAccess(context))

            "openUsageSettings" -> {
                UsageReader.openSettings(context)
                result.success(null)
            }

            "getInstalledApps" -> inBackground(result) { AppLister.list(context) }

            "getUsage" -> {
                val start = call.argument<Number>("start")?.toLong()
                val end = call.argument<Number>("end")?.toLong()
                if (start == null || end == null || end < start) {
                    result.error("bad_arguments", "start and end are required", null)
                    return
                }
                inBackground(result) { UsageReader.read(context, start, end) }
            }

            // ---- Blocker --------------------------------------------------
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(context))

            "openOverlaySettings" -> {
                openOverlaySettings()
                result.success(null)
            }

            "configureBlocker" -> {
                val json = call.argument<String>("json")
                if (json == null) {
                    result.error("bad_arguments", "json is required", null)
                    return
                }
                BlockerConfig.save(context, json)
                BlockerService.sync(context)
                result.success(null)
            }

            "takePendingGate" -> {
                val pkg = BlockerState.pendingGate
                BlockerState.pendingGate = null
                result.success(pkg)
            }

            "passGate" -> {
                val pkg = call.argument<String>("package")
                if (pkg != null) {
                    BlockerState.passedPackage = pkg
                    reopen(pkg)
                }
                result.success(null)
            }

            "goHome" -> {
                goHome()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun openOverlaySettings() {
        val intent =
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    /** Brings the app whose puzzle was solved back to the front. */
    private fun reopen(pkg: String) {
        val launch = context.packageManager.getLaunchIntentForPackage(pkg)
        if (launch == null) {
            goHome()
            return
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(launch)
        } catch (e: Exception) {
            goHome()
        }
    }

    private fun goHome() {
        val home =
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(home)
        } catch (e: Exception) {
            // No home screen to go to; nothing else to do.
        }
    }

    /** Runs [work] off the main thread and sends the answer back on it. */
    private fun inBackground(
        result: Result,
        work: () -> Any?
    ) {
        worker.execute {
            try {
                val value = work()
                mainThread.post { result.success(value) }
            } catch (e: Exception) {
                mainThread.post { result.error("usage_error", e.message, null) }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
