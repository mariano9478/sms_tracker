# Rastreador SOS 📍

App Android (Flutter) para **usar, configurar y administrar** los rastreadores
SOS con GPS **EV07BG (2G)** y **BX (4G)** — firmware DS1/DS2 — sin memorizar
comandos: la app arma los SMS por vos, los envía al chip del dispositivo y lee
las respuestas para mostrarte todo en una interfaz simple.

## Funciones

- **Inicio (dashboard)**: última batería y ubicación conocidas, botón para
  abrir la posición en Google Maps, y acciones rápidas de un toque:
  *Ubicación* (`loc`), *Batería* (`Battery`), *Estado* (`Status`) y
  *Hacer sonar* (`Findme`).
- **Contactos SOS**: administra las 10 posiciones de números de emergencia con
  formularios (avisar por SMS y/o llamada), consulta la lista al dispositivo
  (`A?`) y sincroniza lo que este responde.
- **Botón lateral**: elegí a qué contacto llama (`X1`…`X10`) o desactivalo (`XO`).
- **Sensores y alarmas**: sensor de caída con sensibilidad 1–9 (`FL1,5,1` /
  `FLO`), cerco virtual en metros (`GE01,1,0,100M`) y alerta de no movimiento
  (`NMO1,80M,1` / `NMOO`).
- **Audio y escucha**: escucha remota (`LT1`/`LTO`), volumen del timbre
  (`$rt50$`) y del micrófono (`micvolume10`).
- **Sistema**: zona horaria (`TZ-03`) y umbral de alerta de batería baja
  (`Low1,20`).
- **Mensajes**: conversación tipo chat con el rastreador (comandos enviados y
  respuestas recibidas), con detección automática de links de mapa, y campo de
  comando manual para usuarios avanzados.
- **Parser de respuestas**: extrae porcentaje de batería, coordenadas/links de
  ubicación y lista de contactos de los SMS del rastreador.

Los mensajes se filtran por el número del chip del rastreador, así los SMS del
dispositivo no se mezclan con el historial personal del usuario.

## Cómo está hecha

- **Sin plugins de terceros**: el envío/lectura/recepción de SMS, las
  preferencias y la apertura de URLs se implementan con canales de plataforma
  propios en Kotlin (`android/app/src/main/kotlin/.../MainActivity.kt`):
  - `MethodChannel sms_tracker/methods`: `sendSms`, `queryInbox` (bandeja del
    sistema filtrada por remitente), permisos, `getPref`/`setPref`, `openUrl`.
  - `EventChannel sms_tracker/incoming`: SMS entrantes en vivo.
- **Catálogo de comandos** (`lib/src/command_catalog.dart`): funciones puras
  que generan el texto exacto de cada comando de la guía oficial — cubierto
  por tests (`test/command_catalog_test.dart`).

## Requisitos y compilación

- Flutter 3.24+ (canal stable) y Android SDK 34.
- Android 6.0 (API 23) o superior en el teléfono.

```bash
flutter pub get
flutter run            # con un dispositivo conectado
flutter build apk      # genera el APK (firmado con clave debug)
flutter test           # tests del catálogo de comandos y el parser
```

## Permisos

La app pide `SEND_SMS`, `RECEIVE_SMS` y `READ_SMS`: son imprescindibles para
enviar comandos y leer las respuestas del rastreador. Cada comando es un SMS
común (el plan del teléfono puede cobrarlo) y el chip del rastreador necesita
crédito para responder.

## Notas de uso

1. El rastreador **solo procesa comandos de números registrados** como
   contacto de emergencia: el primer paso es agregar el número del teléfono
   propio desde *Comandos → Contactos SOS* (idealmente en la posición 1).
2. Si no responde a los comandos de registro (`A1,1,1,…`), probá enviarlos
   desde otro teléfono y pedí a la compañía desactivar el contestador
   automático (casilla de voz) de las líneas involucradas.
3. La escucha remota debe usarse de forma responsable y con consentimiento de
   quien porta el dispositivo.

## Posibles mejoras futuras

- Rol de "app de SMS predeterminada" para ocultar los mensajes del rastreador
  de la bandeja del sistema (experiencia 100 % limpia).
- Notificaciones push locales al recibir alertas SOS.
- Soporte multi-dispositivo (varios rastreadores).
