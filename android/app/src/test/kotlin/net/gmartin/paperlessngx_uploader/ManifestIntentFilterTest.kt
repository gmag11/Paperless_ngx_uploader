package net.gmartin.paperlessngx_uploader

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Verifies the intent filters declared in AndroidManifest.xml (tasks 1.2 and 1.3
 * of the add-android-open-with change).
 *
 * Robolectric 4.14.1 supports API 21..35 while the app targets SDK 36, so the
 * tests pin the SDK to 35.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ManifestIntentFilterTest {

    private val applicationId = "net.gmartin.paperlessngx_uploader"
    private val context = RuntimeEnvironment.getApplication()
    private val packageManager = context.packageManager
    private val activity = ComponentName(applicationId, MainActivity::class.java.name)

    private val supportedTypes = listOf(
        "application/pdf",
        "image/jpeg",
        "image/png",
        "image/tiff",
        "image/gif",
        "image/webp",
    )

    /** Task 1.2: the harness loads the app manifest and can run at all. */
    @Test
    fun manifestIsLoadedForTheApplicationId() {
        assertEquals(applicationId, context.packageName)
        val info = packageManager.getPackageInfo(applicationId, PackageManager.GET_ACTIVITIES)
        assertEquals(applicationId, info.packageName)
        val activities = info.activities
        assertTrue(activities != null && activities.any { it.name == activity.className })
    }

    /** Task 1.3: the app appears in the "Open with" chooser for the supported types. */
    @Test
    fun openWithResolvesForPdfAndImages() {
        for (type in supportedTypes) {
            assertTrue(
                "ACTION_VIEW should resolve for $type",
                resolvesForView(type)
            )
        }
    }

    /** Task 1.3: the app must not appear for types it cannot process. */
    @Test
    fun openWithDoesNotResolveForTextOrVideo() {
        assertTrue(!resolvesForView("text/plain"))
        assertTrue(!resolvesForView("video/mp4"))
    }

    /** The VIEW filter is the one that makes the app a chooser target: DEFAULT category. */
    @Test
    fun viewFilterDeclaresDefaultCategoryAndContentOrFileSchemes() {
        val filters = shadowOf(packageManager).getIntentFiltersForActivity(activity)
        val viewFilter = filters.find { it.getAction(0) == Intent.ACTION_VIEW }
        assertTrue(viewFilter != null)
        assertTrue(viewFilter!!.getCategory(0) == Intent.CATEGORY_DEFAULT)
        val schemes = (0 until viewFilter.countDataSchemes())
            .map { index -> viewFilter.getDataScheme(index) }
        assertTrue(schemes.contains("content"))
        assertTrue(schemes.contains("file"))
        val types = (0 until viewFilter.countDataTypes())
            .map { index -> viewFilter.getDataType(index) }
        assertEquals(supportedTypes.sorted(), types.sorted())
    }

    /** Regression: the existing SEND / SEND_MULTIPLE filters are untouched. */
    @Test
    fun sendFiltersStillResolveForAnyType() {
        for (type in listOf("text/plain", "video/mp4", "image/png")) {
            assertTrue("SEND should still resolve for $type", resolvesForAction(Intent.ACTION_SEND, type))
            assertTrue(
                "SEND_MULTIPLE should still resolve for $type",
                resolvesForAction(Intent.ACTION_SEND_MULTIPLE, type)
            )
        }
    }

    private fun resolvesForView(mimeType: String): Boolean =
        resolvesForAction(Intent.ACTION_VIEW, mimeType, Uri.parse("content://provider/document"))

    private fun resolvesForAction(action: String, mimeType: String, data: Uri? = null): Boolean {
        val intent = Intent(action).apply {
            addCategory(Intent.CATEGORY_DEFAULT)
            if (data != null) {
                setDataAndType(data, mimeType)
            } else {
                type = mimeType
            }
        }
        return packageManager
            .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .any { it.activityInfo.packageName == applicationId }
    }

}
