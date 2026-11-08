package com.inocencia.app

import android.app.Activity
import android.content.Context
import android.net.wifi.WifiManager
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Juego en red local: Android descarta los paquetes de difusion (los avisos de las
 * salas) para ahorrar bateria salvo que la app tome un MulticastLock. Mientras dura
 * la partida tambien se mantiene la pantalla encendida.
 */
object LanBridge {
    const val CHANNEL = "com.inocencia.app/lan"
    private var lock: WifiManager.MulticastLock? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "begin" -> {
                        acquire(activity)
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "end" -> {
                        release()
                        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquire(context: Context) {
        if (lock?.isHeld == true) return
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        lock = wifi.createMulticastLock("inocencia-juego").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun release() {
        lock?.let { if (it.isHeld) it.release() }
        lock = null
    }
}
