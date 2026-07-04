package com.techfuture.sms_tracker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Receiver registrado en el manifest: se dispara aunque la app esté
 * cerrada. Si el SMS viene del rastreador configurado, muestra una
 * notificación que al tocarla abre la app en la vista correspondiente.
 *
 * Los mensajes de emergencia ("Help Me" / "Alarm Time", generados por el
 * botón SOS) usan un canal de ALARMA: sonido de alarma que se repite
 * hasta que se atiende, vibración fuerte, color rojo y pantalla completa
 * sobre el bloqueo. Estos se notifican SIEMPRE, incluso con la app en
 * primer plano.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "tracker_alerts"
        const val SOS_CHANNEL_ID = "tracker_sos_alerts"
        const val EXTRA_OPEN_VIEW = "open_view"
        private const val SOS_COLOR = 0xFFD32F2F.toInt()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val prefs =
            context.getSharedPreferences("sms_tracker_prefs", Context.MODE_PRIVATE)
        val tracker = prefs.getString("tracker_number", null) ?: return
        val suffix = tracker.filter { it.isDigit() }.takeLast(8)
        if (suffix.isEmpty()) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val grouped = messages.filterNotNull().groupBy { it.originatingAddress ?: "" }
        for ((address, parts) in grouped) {
            if (!address.filter { it.isDigit() }.endsWith(suffix)) continue
            val body = parts.joinToString(separator = "") { it.messageBody ?: "" }
            if (body.isBlank()) continue

            val isSos = body.lowercase().let {
                it.contains("help me") || it.contains("alarm time")
            }
            // Con la app visible la UI ya muestra la alerta en vivo, pero
            // un SOS igual se notifica: el sonido de alarma es clave.
            if (MainActivity.isInForeground && !isSos) continue
            showNotification(context, body, isSos)
        }
    }

    private fun showNotification(context: Context, body: String, isSos: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createChannels(manager)
        }

        val lower = body.lowercase()
        val isLocation = lower.contains("loc") ||
            lower.contains("geolocation") ||
            lower.contains("lat") ||
            Regex("""(?:[\w-]+\.)+[a-z]{2,}/\S+""").containsMatchIn(lower)

        val view = if (isSos || isLocation) "map" else "messages"
        val title = when {
            isSos -> "🆘 ¡SOS! Botón de emergencia activado"
            isLocation -> "📍 Ubicación del rastreador recibida"
            else -> "Respuesta del rastreador"
        }

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_VIEW, view)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            if (isSos) 911 else view.hashCode(),
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(
            context,
            if (isSos) SOS_CHANNEL_ID else CHANNEL_ID,
        )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body.take(120))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        if (isSos) {
            builder
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setColor(SOS_COLOR)
                .setColorized(true)
                // Se muestra a pantalla completa aun con el teléfono
                // bloqueado (como una llamada entrante).
                .setFullScreenIntent(pendingIntent, true)
                // Pre-Android 8 (el canal maneja esto en 8+):
                .setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioManager.STREAM_ALARM,
                )
                .setVibrate(longArrayOf(0, 600, 250, 600, 250, 1200))
        } else {
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
        }

        val notification = builder.build()
        if (isSos) {
            // El sonido se repite hasta que el usuario atiende la
            // notificación: imposible de ignorar.
            notification.flags = notification.flags or Notification.FLAG_INSISTENT
        }

        manager.notify(
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            notification,
        )
    }

    private fun createChannels(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Respuestas del rastreador",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Avisos cuando el rastreador responde con ubicación, batería u otra información."
            }
        )

        manager.createNotificationChannel(
            NotificationChannel(
                SOS_CHANNEL_ID,
                "Alertas SOS de emergencia",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Alarma cuando se activa el botón SOS del rastreador. No silenciar."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 1200)
                enableLights(true)
                lightColor = Color.RED
                setBypassDnd(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            }
        )
    }
}
