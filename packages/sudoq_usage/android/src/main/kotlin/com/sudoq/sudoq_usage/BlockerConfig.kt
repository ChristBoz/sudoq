package com.sudoq.sudoq_usage

import android.content.Context
import org.json.JSONObject

/**
 * KOTLIN BRIDGE: what the blocker needs to know, saved on the phone so
 * the blocker keeps working while the Flutter app is closed.
 *
 * Flutter decides the content (which apps, which goals) and sends it as
 * JSON through "configureBlocker". Kotlin only stores and reads it.
 *
 * JSON shape:
 * {
 *   "enabled": true,
 *   "historyStartMs": 1731600000000 or null,
 *   "apps": { "com.instagram.android": { "limit": 45, "extra": 0 } }
 * }
 */
class BlockerConfig(
    val enabled: Boolean,
    /** Usage before this moment is ignored (set when history is deleted). */
    val historyStartMs: Long,
    /** Package name -> its rule. Only apps with a goal are listed. */
    val apps: Map<String, Rule>
) {
    class Rule(
        /** Daily goal in minutes. */
        val limitMinutes: Int,
        /** Demo-mode simulated minutes, added to the measured usage. */
        val extraMinutes: Int
    )

    companion object {
        private const val PREFS = "sudoq_blocker"
        private const val KEY = "config"

        @Volatile
        private var cached: BlockerConfig? = null

        fun save(
            context: Context,
            json: String
        ) {
            context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY, json)
                .apply()
            cached = parse(json)
        }

        fun load(context: Context): BlockerConfig {
            cached?.let { return it }
            val json =
                context
                    .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .getString(KEY, null)
            val config = parse(json)
            cached = config
            return config
        }

        private fun parse(json: String?): BlockerConfig {
            if (json == null) return BlockerConfig(false, 0L, emptyMap())
            return try {
                val root = JSONObject(json)
                val apps = HashMap<String, Rule>()
                val list = root.optJSONObject("apps")
                if (list != null) {
                    for (pkg in list.keys()) {
                        val rule = list.getJSONObject(pkg)
                        val limit = rule.optInt("limit", 0)
                        if (limit > 0) apps[pkg] = Rule(limit, rule.optInt("extra", 0))
                    }
                }
                BlockerConfig(
                    enabled = root.optBoolean("enabled", false),
                    historyStartMs = root.optLong("historyStartMs", 0L),
                    apps = apps
                )
            } catch (e: Exception) {
                BlockerConfig(false, 0L, emptyMap())
            }
        }
    }
}

/**
 * What the blocker and the Flutter app tell each other while both are
 * running. Kept in memory only.
 */
object BlockerState {
    /** The app that was just blocked; Flutter shows the puzzle for it. */
    @Volatile
    var pendingGate: String? = null

    /**
     * The app whose puzzle was solved. It stays usable until the user
     * leaves it; opening it again asks for a new puzzle.
     */
    @Volatile
    var passedPackage: String? = null
}
