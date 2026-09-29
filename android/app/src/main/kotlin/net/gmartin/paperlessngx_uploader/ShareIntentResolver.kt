package net.gmartin.paperlessngx_uploader

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Parcelable
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream

/**
 * Outcome of resolving an incoming intent: the local paths that could be read
 * and the display names of the files that could not.
 */
data class ShareResolution(
    val files: List<String> = emptyList(),
    val errors: List<String> = emptyList(),
)

/**
 * Resolves incoming intents (ACTION_VIEW, ACTION_SEND, ACTION_SEND_MULTIPLE)
 * into local file paths. Extracted from MainActivity so the behavior can be
 * verified with JVM tests.
 *
 * A file that cannot be read is reported in [ShareResolution.errors] instead of
 * being silently dropped: no path is produced and no exception escapes.
 */
class ShareIntentResolver(private val context: Context) {

    companion object {
        private const val CACHE_SUBDIR = "shared_files"
        private const val DEFAULT_FILE_NAME = "shared_file"
    }

    /**
     * Resolves [intent] into local file paths (or URL strings for text shares)
     * and the names of the files that could not be read.
     */
    fun resolve(intent: Intent): ShareResolution {
        val files = mutableListOf<String>()
        val errors = mutableListOf<String>()
        val action = intent.action ?: return ShareResolution()

        when (action) {
            // "Open with": a single file delivered in intent.data.
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                if (uri != null &&
                    (uri.scheme == ContentResolver.SCHEME_CONTENT || uri.scheme == ContentResolver.SCHEME_FILE)
                ) {
                    copyUriToCache(uri, files, errors)
                }
            }
            Intent.ACTION_SEND -> {
                val mimeType = intent.type ?: return ShareResolution()
                if (mimeType == "text/plain") {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (!text.isNullOrBlank()) {
                        val trimmed = text.trim()
                        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
                            files.add(trimmed)
                        }
                    }
                } else {
                    val uri = intent.getParcelableExtraCompat<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) copyUriToCache(uri, files, errors)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
                if (!uris.isNullOrEmpty()) {
                    for (uri in uris) copyUriToCache(uri, files, errors)
                }
            }
        }

        return ShareResolution(files, errors)
    }

    /**
     * Reads a content:// or file:// URI. Successes are added to [files] and
     * failures to [errors] using the display name of the file, so the caller can
     * report them. Never throws.
     */
    private fun copyUriToCache(
        uri: Uri,
        files: MutableList<String>,
        errors: MutableList<String>
    ) {
        val resolver = context.contentResolver
        val displayName = queryFileName(resolver, uri) ?: uri.lastPathSegment ?: DEFAULT_FILE_NAME

        try {
            if (uri.scheme == ContentResolver.SCHEME_FILE) {
                val source = uri.path?.let { File(it) }
                if (source == null || !source.canRead()) {
                    errors.add(displayName)
                    return
                }
                files.add(source.absolutePath)
                return
            }

            val cacheDir = File(context.cacheDir, CACHE_SUBDIR)
            if (!cacheDir.exists()) cacheDir.mkdirs()
            val destFile = File(cacheDir, displayName)

            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (!destFile.exists()) {
                errors.add(displayName)
                return
            }
            files.add(destFile.absolutePath)
        } catch (e: Exception) {
            e.printStackTrace()
            errors.add(displayName)
        }
    }

    /**
     * Queries the display name for a content URI using ContentResolver.
     */
    private fun queryFileName(resolver: ContentResolver, uri: Uri): String? {
        var name: String? = null
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        name = cursor.getString(idx)
                    }
                }
            }
        } catch (_: Exception) {
        }
        return name
    }

    private inline fun <reified T : Parcelable> Intent.getParcelableExtraCompat(key: String): T? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(key, T::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableExtra(key)
        }

    private inline fun <reified T : Parcelable> Intent.getParcelableArrayListExtraCompat(key: String): ArrayList<T>? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableArrayListExtra(key, T::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableArrayListExtra(key)
        }
}
