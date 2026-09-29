package net.gmartin.paperlessngx_uploader

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.OpenableColumns
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.File

/**
 * JVM tests for [ShareIntentResolver] (tasks 2.2 and 3.2 of the
 * add-android-open-with change): intent resolution, the copy to cache, and the
 * reporting of files that cannot be read.
 *
 * Robolectric 4.14.1 supports API 21..35 while the app targets SDK 36, so the
 * tests pin the SDK to 35.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ShareIntentResolverTest {

    private val context: Context = RuntimeEnvironment.getApplication()
    private val resolver = ShareIntentResolver(context)
    private val shadowContentResolver = shadowOf(context.contentResolver)

    /**
     * ContentProvider that answers DISPLAY_NAME queries so the display-name path
     * is exercised. The bytes for the copy path are supplied by registering a
     * shadow input stream for the URI.
     */
    class TestProvider : ContentProvider() {
        override fun onCreate(): Boolean = true

        override fun query(
            uri: Uri,
            projection: Array<String>?,
            selection: String?,
            selectionArgs: Array<String>?,
            sortOrder: String?
        ): Cursor {
            val cursor = MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME))
            cursor.addRow(arrayOf(DISPLAY_NAME))
            return cursor
        }

        override fun getType(uri: Uri): String? = null

        override fun insert(uri: Uri, values: ContentValues?): Uri? = null

        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0

        override fun update(
            uri: Uri,
            values: ContentValues?,
            selection: String?,
            selectionArgs: Array<String>?
        ): Int = 0
    }

    private fun registerProvider() {
        Robolectric.buildContentProvider(TestProvider::class.java).create(AUTHORITY)
    }

    private fun viewIntent(uri: Uri) = Intent(Intent.ACTION_VIEW).apply { data = uri }

    @Test
    fun openWithCopiesReadableContentUriToCache() {
        registerProvider()
        val uri = Uri.parse("content://$AUTHORITY/document.pdf")
        shadowContentResolver.registerInputStream(uri, ByteArrayInputStream(CONTENT.toByteArray()))

        val result = resolver.resolve(viewIntent(uri))

        assertTrue(result.errors.isEmpty())
        assertEquals(1, result.files.size)
        val copied = File(result.files.first())
        assertTrue(copied.exists())
        assertEquals(DISPLAY_NAME, copied.name)
        assertEquals(CONTENT, copied.readText())
        assertEquals(File(context.cacheDir, "shared_files").absolutePath, copied.parent)
    }

    @Test
    fun openWithReportsUnreadableContentUriInsteadOfDroppingIt() {
        // No provider is registered for this authority: reading throws.
        val uri = Uri.parse("content://unregistered_authority/secret.pdf")

        val result = resolver.resolve(viewIntent(uri))

        assertTrue(result.files.isEmpty())
        // Without a provider the display name falls back to the last path segment.
        assertEquals(listOf("secret.pdf"), result.errors)
    }

    @Test
    fun openWithKeepsReadableFileUriPaths() {
        val file = File.createTempFile("open-with", ".pdf")
        file.writeText(CONTENT)

        val result = resolver.resolve(viewIntent(Uri.fromFile(file)))

        assertTrue(result.errors.isEmpty())
        assertEquals(listOf(file.absolutePath), result.files)
    }

    @Test
    fun openWithReportsUnreadableFileUri() {
        val missing = File(context.cacheDir, "shared_files/missing.pdf")
        val result = resolver.resolve(viewIntent(Uri.fromFile(missing)))

        assertTrue(result.files.isEmpty())
        assertEquals(listOf("missing.pdf"), result.errors)
    }

    @Test
    fun openWithIgnoresUrisOutsideContentAndFileSchemes() {
        val result = resolver.resolve(viewIntent(Uri.parse("http://example.com/document.pdf")))

        assertTrue(result.files.isEmpty())
        assertTrue(result.errors.isEmpty())
    }

    @Test
    fun openWithIgnoresIntentsWithoutData() {
        val result = resolver.resolve(Intent(Intent.ACTION_VIEW))

        assertTrue(result.files.isEmpty())
        assertTrue(result.errors.isEmpty())
    }

    @Test
    fun sendStillResolvesSharedTextUrls() {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, "https://example.com/document.pdf")
        }

        val result = resolver.resolve(intent)

        assertTrue(result.errors.isEmpty())
        assertEquals(listOf("https://example.com/document.pdf"), result.files)
    }

    @Test
    fun sendCopiesStreamedFiles() {
        registerProvider()
        val uri = Uri.parse("content://$AUTHORITY/photo.png")
        shadowContentResolver.registerInputStream(uri, ByteArrayInputStream(CONTENT.toByteArray()))

        val result = resolver.resolve(
            Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
            }
        )

        assertTrue(result.errors.isEmpty())
        assertEquals(1, result.files.size)
        assertEquals(DISPLAY_NAME, File(result.files.first()).name)
    }

    @Test
    fun sendMultipleReportsTheFilesItCouldNotRead() {
        registerProvider()
        val readable = Uri.parse("content://$AUTHORITY/ok.pdf")
        shadowContentResolver.registerInputStream(readable, ByteArrayInputStream(CONTENT.toByteArray()))
        val unreadable = Uri.parse("content://unregistered_authority/broken.pdf")

        val result = resolver.resolve(
            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, arrayListOf(readable, unreadable))
            }
        )

        assertEquals(1, result.files.size)
        assertEquals(listOf("broken.pdf"), result.errors)
    }

    @Test
    fun resolutionNeverThrowsForUnreadableFiles() {
        val uri = Uri.parse("content://unregistered_authority/broken.pdf")
        val result = resolver.resolve(viewIntent(uri))

        // Reaching this point at all proves no exception escaped the resolver.
        assertEquals(listOf("broken.pdf"), result.errors)
    }

    private companion object {
        const val AUTHORITY = "test_authority"
        const val DISPLAY_NAME = "display-name.pdf"
        const val CONTENT = "pdf bytes"
    }
}
