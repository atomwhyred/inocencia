package com.inocencia.app

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Puente nativo: version de Android, RAM total, carpeta de las librerias nativas (donde
 * llama.cpp busca las variantes de CPU) y permiso "Acceso a todos los
 * archivos" (Android 11+). El acceso por SAF (descriptor
 * /proc/self/fd/N) se anadira tras el spike descrito en el plan (Fase 2).
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
                    else -> result.notImplemented()
                }
            }
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
