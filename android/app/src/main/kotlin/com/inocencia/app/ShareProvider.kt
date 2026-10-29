package com.inocencia.app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Sirve a otras apps (ShareIt, Zapya, Bluetooth...) los archivos que la app decide compartir,
 * sin copiarlos: el modelo pesa GB y un FileProvider normal solo ve la memoria interna
 * principal, no la tarjeta SD.
 *
 * Solo atiende URI creadas con [register] (un token por archivo): una app no puede pedir
 * rutas arbitrarias. El permiso de lectura lo concede cada Intent de compartir.
 */
class ShareProvider : ContentProvider() {
    companion object {
        const val AUTHORITY = "com.inocencia.app.share"
        private const val MAX_TOKENS = 200

        private val files = ConcurrentHashMap<String, File>()

        /** content://com.inocencia.app.share/<token>/<nombre> */
        fun register(file: File): Uri {
            if (files.size >= MAX_TOKENS) files.clear()
            val token = UUID.randomUUID().toString()
            files[token] = file
            return Uri.Builder()
                .scheme("content")
                .authority(AUTHORITY)
                .appendPath(token)
                .appendPath(file.name)
                .build()
        }

        fun mimeOf(file: File): String = when (file.extension.lowercase()) {
            "pdf" -> "application/pdf"
            "db", "sqlite", "sqlite3" -> "application/vnd.sqlite3"
            else -> "application/octet-stream"
        }
    }

    override fun onCreate(): Boolean = true

    private fun fileFor(uri: Uri): File? = uri.pathSegments.firstOrNull()?.let { files[it] }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        val file = fileFor(uri) ?: return null
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns, 1)
        cursor.addRow(
            Array<Any?>(columns.size) { i ->
                when (columns[i]) {
                    OpenableColumns.DISPLAY_NAME -> file.name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            },
        )
        return cursor
    }

    override fun getType(uri: Uri): String? = fileFor(uri)?.let { mimeOf(it) }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Solo lectura")
        val file = fileFor(uri) ?: throw FileNotFoundException(uri.toString())
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException()

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException()
}
