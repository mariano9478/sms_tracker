package com.techfuture.sms_tracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Puente nativo para operar SMS sin depender de plugins de terceros.
 *
 * MethodChannel  sms_tracker/methods : enviar SMS, leer bandeja de entrada,
 *                                      permisos, preferencias y abrir URLs.
 * EventChannel   sms_tracker/incoming: stream de SMS entrantes en vivo.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "sms_tracker/methods"
        private const val EVENT_CHANNEL = "sms_tracker/incoming"
        private const val PERMISSION_REQUEST_CODE = 4711

        /** Usado por [SmsReceiver] para no notificar con la app visible. */
        @JvmStatic
        @Volatile
        var isInForeground = false
    }

    private val smsPermissions = arrayOf(
        Manifest.permission.SEND_SMS,
        Manifest.permission.RECEIVE_SMS,
        Manifest.permission.READ_SMS,
    )

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var smsReceiver: BroadcastReceiver? = null
    private var methodChannel: MethodChannel? = null

    /** Vista pedida por una notificación tocada antes de que Dart arranque. */
    private var pendingLaunchView: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingLaunchView = intent?.getStringExtra(SmsReceiver.EXTRA_OPEN_VIEW)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val view = intent.getStringExtra(SmsReceiver.EXTRA_OPEN_VIEW) ?: return
        pendingLaunchView = view
        // App ya corriendo: se avisa a Dart directamente.
        methodChannel?.invokeMethod("launchView", view)
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermissions" -> result.success(hasSmsPermissions())
                    "consumeLaunchView" -> {
                        result.success(pendingLaunchView)
                        pendingLaunchView = null
                    }
                    "requestPermissions" -> requestSmsPermissions(result)
                    "sendSms" -> {
                        val to = call.argument<String>("to")
                        val body = call.argument<String>("body")
                        if (to.isNullOrBlank() || body.isNullOrBlank()) {
                            result.error("bad_args", "Faltan 'to' o 'body'", null)
                        } else {
                            sendSms(to, body, result)
                        }
                    }
                    "queryInbox" -> {
                        val suffix = call.argument<String>("suffix") ?: ""
                        val limit = call.argument<Int>("limit") ?: 300
                        try {
                            result.success(queryInbox(suffix, limit))
                        } catch (e: Exception) {
                            result.error("query_failed", e.message, null)
                        }
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("bad_args", "Falta 'url'", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("open_failed", e.message, null)
                            }
                        }
                    }
                    "getPref" -> {
                        val key = call.argument<String>("key")
                        result.success(if (key == null) null else prefs().getString(key, null))
                    }
                    "setPref" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key != null) {
                            prefs().edit().putString(key, value).apply()
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    registerSmsReceiver(events)
                }

                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                }
            })
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        super.onDestroy()
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences("sms_tracker_prefs", Context.MODE_PRIVATE)

    private fun hasSmsPermissions(): Boolean = smsPermissions.all {
        ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        if (hasSmsPermissions()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("in_progress", "Ya hay una solicitud de permisos en curso", null)
            return
        }
        pendingPermissionResult = result
        // En Android 13+ se pide también el permiso de notificaciones para
        // poder avisar cuando el rastreador responde. No es bloqueante:
        // hasSmsPermissions() solo exige los permisos de SMS.
        val toRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            smsPermissions + Manifest.permission.POST_NOTIFICATIONS
        } else {
            smsPermissions
        }
        ActivityCompat.requestPermissions(this, toRequest, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            pendingPermissionResult?.success(hasSmsPermissions())
            pendingPermissionResult = null
        }
    }

    private fun sendSms(to: String, body: String, result: MethodChannel.Result) {
        try {
            val manager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = manager.divideMessage(body)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(to, null, parts, null, null)
            } else {
                manager.sendTextMessage(to, null, body, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("send_failed", e.message, null)
        }
    }

    /**
     * Lee la bandeja de entrada del sistema y devuelve solo los mensajes
     * cuyo remitente termina con [suffix] (últimos dígitos del número del
     * rastreador), para no mezclar los SMS personales del usuario.
     */
    private fun queryInbox(suffix: String, limit: Int): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val iAddress = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val iBody = cursor.getColumnIndex(Telephony.Sms.BODY)
            val iDate = cursor.getColumnIndex(Telephony.Sms.DATE)
            while (cursor.moveToNext() && out.size < limit) {
                val address = cursor.getString(iAddress) ?: continue
                if (suffix.isNotEmpty() && !digitsOf(address).endsWith(suffix)) continue
                out.add(
                    mapOf(
                        "address" to address,
                        "body" to (cursor.getString(iBody) ?: ""),
                        "date" to cursor.getLong(iDate),
                    )
                )
            }
        }
        return out
    }

    private fun digitsOf(value: String): String = value.filter { it.isDigit() }

    private fun registerSmsReceiver(events: EventChannel.EventSink?) {
        unregisterSmsReceiver()
        val sink = events ?: return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val smsIntent = intent ?: return
                if (smsIntent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
                val messages =
                    Telephony.Sms.Intents.getMessagesFromIntent(smsIntent) ?: return
                // Un SMS largo llega en varias partes: se agrupan por remitente.
                val grouped = messages.filterNotNull().groupBy { it.originatingAddress ?: "" }
                for ((address, parts) in grouped) {
                    val body = parts.joinToString(separator = "") { it.messageBody ?: "" }
                    sink.success(
                        mapOf(
                            "address" to address,
                            "body" to body,
                            "date" to System.currentTimeMillis(),
                        )
                    )
                }
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        smsReceiver = receiver
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
                // Ya estaba desregistrado.
            }
        }
        smsReceiver = null
    }
}
