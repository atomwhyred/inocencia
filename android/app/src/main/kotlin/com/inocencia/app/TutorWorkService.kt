package com.inocencia.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Servicio en primer plano mientras el modelo trabaja (tutor, tarjetas, quiz, carga).
 *
 * Con la app fuera de la pantalla Android la congela o la deja solo en los núcleos
 * pequeños, y una respuesta de 30 s pasaba a tardar diez minutos. Un servicio en primer
 * plano (con su aviso fijo) mantiene el proceso con prioridad de primer plano, y el
 * wake lock parcial deja la CPU despierta aunque se apague la pantalla.
 *
 * No sobrevive a cerrar la app desde Recientes: el modelo vive en el motor de Flutter
 * de la Activity, que se destruye con ella. Por eso `stopWithTask="true"`.
 */
class TutorWorkService : Service() {
    companion object {
        private const val CHANNEL_WORK = "tutor_trabajando"
        private const val CHANNEL_DONE = "tutor_listo"
        private const val ID_WORK = 7101
        private const val ID_DONE = 7102
        private const val ACTION_DONE = "com.inocencia.app.TUTOR_DONE"

        /** Tope de seguridad del wake lock: ninguna respuesta tarda tanto. */
        private const val WAKE_LOCK_MS = 20 * 60 * 1000L

        /**
         * Arranca el servicio. Solo se puede con la app en pantalla (Android 12+): la app
         * lo pide al empezar a generar, justo después de que el niño pulse Enviar.
         */
        fun start(context: Context): Boolean = try {
            context.startForegroundService(Intent(context, TutorWorkService::class.java))
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException si la app ya estaba en segundo plano.
            false
        }

        /** Para el servicio; con [notifyDone], deja un aviso de que ya terminó. */
        fun stop(context: Context, notifyDone: Boolean) {
            context.stopService(Intent(context, TutorWorkService::class.java))
            if (notifyDone) showDone(context)
        }

        /** Quita el aviso de "ya respondió" (al volver a la app ya no hace falta). */
        fun clearDone(context: Context) {
            context.getSystemService(NotificationManager::class.java)?.cancel(ID_DONE)
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(
                context,
                0,
                open,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun ensureChannels(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_WORK, "Tutor trabajando", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Aviso fijo mientras Toco prepara una respuesta con la app fuera de la pantalla"
                    setShowBadge(false)
                },
            )
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_DONE, "Respuesta lista", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Avisa cuando Toco termina y la app no está en pantalla"
                },
            )
        }

        private fun showDone(context: Context) {
            ensureChannels(context)
            // Sin el texto de la respuesta ni el nombre del niño: se ve en la pantalla de bloqueo.
            val n = Notification.Builder(context, CHANNEL_DONE)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("¡Toco ya terminó!")
                .setContentText("Toca para volver a inocencIA.")
                .setContentIntent(openAppIntent(context))
                .setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .build()
            try {
                context.getSystemService(NotificationManager::class.java)?.notify(ID_DONE, n)
            } catch (e: SecurityException) {
                // Sin permiso de notificaciones (Android 13+): no pasa nada.
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels(this)
        val notification = Notification.Builder(this, CHANNEL_WORK)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Toco está pensando…")
            .setContentText("Puedes salir de la app o apagar la pantalla. No la cierres desde Recientes.")
            .setContentIntent(openAppIntent(this))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setProgress(0, 0, true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ID_WORK, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID_WORK, notification)
        }
        if (wakeLock?.isHeld != true) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "inocencia:tutor").apply {
                setReferenceCounted(false)
                acquire(WAKE_LOCK_MS)
            }
        }
        // Si Android matara el proceso, no tiene sentido rearrancar el servicio sin el modelo.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
