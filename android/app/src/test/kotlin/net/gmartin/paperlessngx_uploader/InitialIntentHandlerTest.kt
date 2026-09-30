package net.gmartin.paperlessngx_uploader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

/**
 * JVM tests for [InitialIntentHandler]: the launch intent is delivered exactly
 * once, even after Android recreates the task (and the process) with the
 * original intent, while a genuinely different launch intent is still handled.
 *
 * Robolectric 4.14.1 supports API 21..35 while the app targets SDK 36, so the
 * tests pin the SDK to 35.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class InitialIntentHandlerTest {

    private val context: Context = RuntimeEnvironment.getApplication()

    private fun handler() = InitialIntentHandler(ShareIntentResolver(context))

    private fun readableFileViewIntent(prefix: String = "launch"): Intent {
        val file = File.createTempFile(prefix, ".pdf")
        file.writeText("pdf bytes")
        return Intent(Intent.ACTION_VIEW).apply { data = Uri.fromFile(file) }
    }

    @Test
    fun capturesTheLaunchIntentOnce() {
        val handler = handler()

        assertTrue(handler.capture(readableFileViewIntent(), null))
        val resolution = handler.consume()
        assertTrue(resolution != null && resolution.files.size == 1)
        // A second consumption returns nothing.
        assertNull(handler.consume())
    }

    @Test
    fun doesNotRedeliverTheSameLaunchIntentAfterProcessDeathRecreation() {
        val first = handler()
        val intent = readableFileViewIntent()
        assertTrue(first.capture(intent, null))
        first.consume()

        val savedState = Bundle()
        first.saveState(savedState)

        // New instance, as created by Android after the process was killed.
        val recreated = handler()
        assertTrue(recreated.capture(intent, savedState))
        // Nothing is re-delivered from the restored launch intent.
        assertNull(recreated.consume())
    }

    @Test
    fun stillHandlesADifferentLaunchIntentAfterRecreation() {
        val first = handler()
        assertTrue(first.capture(readableFileViewIntent("first"), null))
        first.consume()

        val savedState = Bundle()
        first.saveState(savedState)

        // A different file must not be swallowed by the guard.
        val recreated = handler()
        assertTrue(recreated.capture(readableFileViewIntent("second"), savedState))
        val resolution = recreated.consume()
        assertTrue(resolution != null && resolution.files.size == 1)
    }

    @Test
    fun ignoresLaunchIntentsWithoutContentAndSavesNoGuard() {
        val handler = handler()
        val savedState = Bundle()

        assertFalse(handler.capture(Intent(Intent.ACTION_MAIN), null))
        assertNull(handler.consume())
        handler.saveState(savedState)
        assertFalse(savedState.containsKey(InitialIntentHandler.KEY_HANDLED_ID))
    }

    @Test
    fun capturesUnreadableLaunchIntentSoItIsReported() {
        val handler = handler()
        val missing = File(context.cacheDir, "shared_files/missing.pdf")
        val intent = Intent(Intent.ACTION_VIEW).apply { data = Uri.fromFile(missing) }

        assertTrue(handler.capture(intent, null))
        val resolution = handler.consume()
        assertEquals(listOf("missing.pdf"), resolution?.errors)
    }

    @Test
    fun resetClearsTheCapturedResolution() {
        val handler = handler()

        assertTrue(handler.capture(readableFileViewIntent(), null))
        handler.reset()
        assertNull(handler.consume())
    }
}
