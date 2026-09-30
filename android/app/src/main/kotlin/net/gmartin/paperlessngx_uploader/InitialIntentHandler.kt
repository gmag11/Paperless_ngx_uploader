package net.gmartin.paperlessngx_uploader

import android.content.Intent
import android.os.Bundle

/**
 * Owns the launch ("initial") intent captured when [MainActivity] is created and
 * the guard that prevents it from being delivered twice.
 *
 * Android recreates a task with its original launch intent after the process is
 * killed in the background. `Activity.setIntent(ACTION_MAIN)` only mutates the
 * in-memory intent, so the same file would otherwise be resolved and uploaded
 * again. The identity of the handled intent is written to the saved instance
 * state, which survives that process death but is discarded together with the
 * task. A genuinely new "open with" (different identity) is still processed.
 *
 * Extracted from [MainActivity] so the guard can be verified with JVM tests.
 */
class InitialIntentHandler(private val resolver: ShareIntentResolver) {

    companion object {
        const val KEY_HANDLED_ID = "net.gmartin.paperlessngx_uploader.initial_intent_id"
    }

    private var pending: ShareResolution? = null
    private var handledId: String? = null

    /**
     * Captures the launch [intent]. Returns `true` when the caller must replace
     * the activity intent with `ACTION_MAIN`, either because a new resolution
     * was captured or because this exact launch was already delivered before
     * the activity (or the process) was recreated.
     */
    fun capture(intent: Intent, savedState: Bundle?): Boolean {
        val id = resolver.identityOf(intent) ?: return false

        if (savedState?.getString(KEY_HANDLED_ID) == id) {
            // This exact launch was already delivered before the recreation.
            handledId = id
            return true
        }

        val resolution = resolver.resolve(intent)
        if (!resolution.hasContent()) return false

        handledId = id
        pending = resolution
        return true
    }

    /**
     * Persists the handled identity so that a recreation after a process death
     * does not deliver the launch intent again.
     */
    fun saveState(outState: Bundle) {
        handledId?.let { outState.putString(KEY_HANDLED_ID, it) }
    }

    /** Returns and clears the captured resolution (meant to be called once). */
    fun consume(): ShareResolution? {
        val resolution = pending
        pending = null
        return resolution
    }

    fun reset() {
        pending = null
    }
}
