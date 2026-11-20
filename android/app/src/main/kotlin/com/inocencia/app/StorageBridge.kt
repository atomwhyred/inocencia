package com.inocencia.app

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Puente nativo: version de Android, RAM total, carpeta de las librerias nativas (donde
 * llama.cpp busca las variantes de CPU), permiso "Acceso a todos los
 * archivos" (Android 11+), espacio libre de un volumen y el menu de compartir archivos
 * (el modelo, la base y los libros se pasan a otros dispositivos sin internet).
 */
object StorageBridge {
    const val CHANNEL = "com.inocencia.app/storage"

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "totalRamBytes" -> result.success(totalRamBytes(activity))
                    "nativeLibraryDir" -> result.success(activity.applicationInfo.nativeLibraryDir)
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> {
                        requestAllFilesAccess(activity)
                        result.success(null)
                    }
                    "freeBytes" -> result.success(freeBytes(call.argument<String>("path")))
                    "shareFiles" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        result.success(shareFiles(activity, paths, call.argument<String>("title")))
                    }
                    "thermalStatus" -> result.success(thermalStatus(activity))
                    // Monótono desde el encendido: el bloqueo del PIN no se salta cambiando la hora.
                    "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                    "keepScreenOn" -> {
                        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        if (call.argument<Boolean>("on") == true) {
                            activity.window.addFlags(flag)
                        } else {
                            activity.window.clearFlags(flag)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Estado termico de Android (0 normal ... 6 apagado por calor); -1 antes de
     * Android 10. Explica si un telefono va lento porque se esta frenando por calor.
     */
    private fun thermalStatus(context: Context): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return -1
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.currentThermalStatus
    }

    /** Espacio libre del volumen que contiene [path] (sube hasta una carpeta que exista). */
    private fun freeBytes(path: String?): Long? {
        var dir = path?.let { File(it) } ?: return null
        while (!dir.exists()) dir = dir.parentFile ?: return null
        return try {
            StatFs(dir.path).availableBytes
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    /**
     * Abre el menu de compartir de Android con estos archivos. No se copian: el
     * [ShareProvider] los sirve directamente. Devuelve false si no hay nada que compartir.
     */
    private fun shareFiles(activity: Activity, paths: List<String>, title: String?): Boolean {
        // Nunca los datos privados de la app (perfiles, historial, PIN): solo el modelo, la
        // base y los libros, que están fuera de dataDir.
        val privateDir = File(activity.applicationInfo.dataDir).canonicalFile
        val files = paths.map { File(it) }.filter {
            it.isFile && it.canRead() && !it.canonicalFile.startsWith(privateDir)
        }
        if (files.isEmpty()) return false
        val uris = files.map { ShareProvider.register(it) }
        val mimes = files.map { ShareProvider.mimeOf(it) }.distinct()
        val mime = if (mimes.size == 1) mimes[0] else "*/*"
        val send = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE)
                .putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
        send.type = mime
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val clip = ClipData.newRawUri("", uris[0])
        uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
        send.clipData = clip
        val chooser = Intent.createChooser(send, title)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(chooser)
        return true
    }

    private fun totalRamBytes(activity: Activity): Long {
        val info = ActivityManager.MemoryInfo()
        (activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
        return info.totalMem
    }

    // Antes de Android 11 no existe este permiso: no hay nada que conceder.
    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()

    private fun requestAllFilesAccess(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
        } catch (e: ActivityNotFoundException) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
        }
    }
}
