package com.sudoq.sudoq_usage

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

/**
 * KOTLIN BRIDGE: the entry point Flutter talks to.
 *
 * It only routes calls. The real work is in [UsageReader] and [AppLister].
 * Being a plugin (not code in MainActivity) means it is also available to
 * the background check, which runs without the app being open.
 *
 * Methods on the "sudoq_usage" channel:
 *  - hasUsageAccess     -> Boolean
 *  - openUsageSettings  -> opens the Android "Usage access" screen
 *  - getInstalledApps   -> List of {package, name, category}
 *  - getUsage(start,end)-> {eventCount, usageMs: {package: milliseconds}}
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

            else -> result.notImplemented()
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
