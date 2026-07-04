package com.techfuture.sms_tracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Receiver registrado en el manifest: se dispara aunque la app esté
 * cerrada. Si el SMS viene del rastreador configurado, muestra una
 * notificación que al tocarla abre la app en la vista correspondiente
 * (mapa para ubicaciones, mensajes para el resto).
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "tracker_alerts"
        const val EXTRA_OPEN_VIEW = "open_view"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        // Con la app en primer plano la UI ya se actualiza en vivo:
        // no hace falta molestar con una notificación.
        if (MainActivity.isInForeground) return

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
            if (body.isNotBlank()) {
                showNotification(context, body)
            }
        }
    }

    private fun showNotification(context: Context, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val lower = body.lowercase()
        val isLocation = lower.contains("loc") ||
            lower.contains("geolocation") ||
            lower.contains("lat") ||
            Regex("""(?:[\w-]+\.)+[a-z]{2,}/\S+""").containsMatchIn(lower)
        val view = if (isLocation) "map" else "messages"
        val title =
            if (isLocation) "📍 Ubicación del rastreador recibida"
            else "Respuesta del rastreador"

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
        }

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_OPEN_VIEW, view)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            view.hashCode(),
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body.take(120))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
}
