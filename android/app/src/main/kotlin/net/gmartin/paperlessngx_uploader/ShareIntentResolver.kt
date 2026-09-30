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
import java.io.InputStream

/**
 * Outcome of resolving an incoming intent: the local paths that could be read
 * and the display names of the files that could not.
 */
data class ShareResolution(
    val files: List<String> = emptyList(),
    val errors: List<String> = emptyList(),
) {
    /** True when the intent delivered something worth handling (readable file or failure to report). */
    fun hasContent(): Boolean = files.isNotEmpty() || errors.isNotEmpty()
}

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

        /** Copies older than this are removed on app start, so the share cache stays bounded. */
        private const val CACHE_MAX_AGE_MILLIS = 24 * 60 * 60 * 1000L
    }

    /**
     * Removes copies left in `cacheDir/shared_files` by previous deliveries once
     * they are older than [CACHE_MAX_AGE_MILLIS]. Called on app start: stale by
     * that margin means the upload they fed has long finished, so deleting them
     * cannot race with an in-flight upload. Never throws.
     */
    fun pruneStaleCache() {
        try {
            val cacheDir = File(context.cacheDir, CACHE_SUBDIR)
            if (!cacheDir.isDirectory) return
            val cutoff = System.currentTimeMillis() - CACHE_MAX_AGE_MILLIS
            cacheDir.listFiles()?.forEach { file ->
                if (file.isFile && file.lastModified() < cutoff) {
                    file.delete()
                }
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Resolves [intent] into local file paths (or URL strings for text shares)
     * and the names of the files that could not be read.
     */
    fun resolve(intent: Intent): ShareResolution {
        val files = mutableListOf<String>()
        val errors = mutableListOf<String>()
        val usedNames = mutableSetOf<String>()
        val action = intent.action ?: return ShareResolution()

        when (action) {
            // "Open with": a single file delivered in intent.data.
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                if (uri != null &&
                    (uri.scheme == ContentResolver.SCHEME_CONTENT || uri.scheme == ContentResolver.SCHEME_FILE)
                ) {
                    copyUriToCache(uri, files, errors, usedNames)
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
                    if (uri != null) copyUriToCache(uri, files, errors, usedNames)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
                if (!uris.isNullOrEmpty()) {
                    for (uri in uris) copyUriToCache(uri, files, errors, usedNames)
                }
            }
        }

        return ShareResolution(files, errors)
    }

    /**
     * Stable identity of an incoming intent, used to avoid delivering the same
     * launch intent twice after the task is restored. Returns null when the
     * intent carries nothing the app would resolve.
     */
    fun identityOf(intent: Intent): String? {
        val action = intent.action ?: return null
        val detail = when (action) {
            Intent.ACTION_VIEW -> intent.data?.toString()
            Intent.ACTION_SEND -> {
                val stream = intent.getParcelableExtraCompat<Uri>(Intent.EXTRA_STREAM)
                stream?.toString()
                    ?: intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
            }
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
                    ?.joinToString("|") { it.toString() }
            else -> null
        } ?: return null
        return "$action:$detail"
    }

    /**
     * Reads a content:// or file:// URI and copies it to the app cache, so the
     * upload pipeline always works on an app-owned file. Successes are added to
     * [files] and failures to [errors] using the display name of the file, so
     * the caller can report them. Never throws.
     */
    private fun copyUriToCache(
        uri: Uri,
        files: MutableList<String>,
        errors: MutableList<String>,
        usedNames: MutableSet<String>
    ) {
        val resolver = context.contentResolver
        val displayName = queryFileName(resolver, uri) ?: uri.lastPathSegment ?: DEFAULT_FILE_NAME

        try {
            val source = openSource(resolver, uri)
            if (source == null) {
                errors.add(displayName)
                return
            }

            val cacheDir = File(context.cacheDir, CACHE_SUBDIR)
            if (!cacheDir.exists()) cacheDir.mkdirs()
            val destFile = uniqueDestination(cacheDir, displayName, usedNames)

            source.use { input ->
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
     * Opens a readable stream for a content:// or file:// URI, or returns null
     * when the source cannot be read.
     */
    private fun openSource(resolver: ContentResolver, uri: Uri): InputStream? {
        if (uri.scheme == ContentResolver.SCHEME_FILE) {
            val path = uri.path ?: return null
            val source = File(path)
            if (!source.canRead()) return null
            return source.inputStream()
        }
        return resolver.openInputStream(uri)
    }

    /**
     * Destination file that does not collide with another file copied during the
     * same resolution (two shared files can share a display name). The suffix
     * keeps both files available instead of overwriting the first one.
     */
    private fun uniqueDestination(
        cacheDir: File,
        displayName: String,
        usedNames: MutableSet<String>
    ): File {
        var name = displayName
        if (!usedNames.add(name)) {
            val dot = displayName.lastIndexOf('.')
            val base = if (dot > 0) displayName.substring(0, dot) else displayName
            val extension = if (dot > 0) displayName.substring(dot) else ""
            var index = 1
            do {
                name = "${base}_$index$extension"
                index++
            } while (!usedNames.add(name))
        }
        return File(cacheDir, name)
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
