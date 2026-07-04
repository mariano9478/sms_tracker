<div align="center">

# 📍 Rastreador SOS

**App Android para usar, configurar y administrar rastreadores GPS SOS
(EV07BG 2G / BX 4G) por SMS — sin memorizar comandos.**

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Plataforma-Android%206.0%2B-3DDC84?logo=android&logoColor=white)](#requisitos)
[![License: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Sin plugins de terceros](https://img.shields.io/badge/Dependencias-0%20plugins-success)](#arquitectura)

*La app arma los SMS por vos, los envía al chip del rastreador y lee las
respuestas para mostrarte todo en una interfaz simple, en español.*

</div>

---

## ¿Qué es esto?

Los rastreadores SOS **EV07BG (2G)** y **BX (4G)** — firmware DS1/DS2 — se
configuran enviando comandos por SMS con sintaxis del estilo
`A1,1,1,1138889888` o `GE01,1,0,100M`. Funciona, pero es fácil equivocarse y
difícil de recordar.

**Rastreador SOS** reemplaza esos comandos por pantallas y formularios:
tocás *"Sensor de caída"*, movés un slider de sensibilidad, y la app envía el
SMS exacto. Cuando el rastreador responde, la app lee el mensaje, lo
interpreta (batería, ubicación, contactos) y te lo muestra ordenado —
separado de tus SMS personales.

## ✨ Funciones

| | |
|---|---|
| 🏠 **Dashboard** | Última batería y ubicación conocidas, apertura en Google Maps y acciones rápidas de un toque: Ubicación, Batería, Estado y Hacer sonar. |
| 🗺️ **Mapa integrado** | Última ubicación conocida sobre un mapa (OpenStreetMap) con pin y zoom. Si el rastreador manda la posición como link (smart-locator), la app sigue su redirección a Google Maps, extrae las coordenadas y la muestra igual en el mapa. |
| 🔔 **Notificaciones** | Aviso instantáneo cuando el rastreador responde — incluso con la app cerrada. Al tocarlo, la app se abre directo en el mapa o en los mensajes. |
| 🆘 **Alerta SOS** | Cuando se activa el botón de emergencia ("Help Me"): notificación de ALARMA con sonido que se repite hasta atenderla, vibración, pantalla completa sobre el bloqueo, y dentro de la app una alerta roja pulsante con acciones directas (ver en el mapa / llamar al rastreador). |
| 🆘 **Contactos SOS** | Administra las 10 posiciones de números de emergencia (aviso por SMS y/o llamada), consulta la lista al dispositivo y sincroniza su respuesta. |
| 🔘 **Botón lateral** | Elegí a qué contacto llama el botón de llamada rápida, o desactivalo. |
| 🚨 **Sensores y alarmas** | Sensor de caída (sensibilidad 1–9), cerco virtual en metros y alerta de no movimiento. |
| 🎙️ **Audio y escucha** | Escucha remota (micrófono silencioso), volumen del timbre y del micrófono. |
| ⚙️ **Sistema** | Zona horaria y umbral de la alerta de batería baja. |
| 💬 **Mensajes** | Conversación tipo chat con el rastreador, detección automática de links de mapa y campo de comando manual para usuarios avanzados. |
| 🔍 **Parser de respuestas** | Extrae porcentaje de batería, coordenadas/links y lista de contactos de los SMS recibidos. |

Todos los formularios muestran **una vista previa del SMS exacto** antes de
enviarlo, así siempre sabés qué le llega al dispositivo.

## 📟 Comandos soportados

La app cubre el catálogo completo de la guía oficial:

| Función | Comando | Pantalla |
| :--- | :--- | :--- |
| Agregar contacto SOS | `A(n),(sms),(llamada),(número)` | Contactos SOS |
| Ver contactos | `A?` | Contactos SOS |
| Eliminar contacto | `removeA(n)` | Contactos SOS |
| Botón lateral | `X(n)` / `XO` | Botón lateral |
| Sensor de caída | `FL1,(1-9),(0/1)` / `FLO` | Sensores |
| Cerco virtual | `GE0(n),1,0,(m)M` | Sensores |
| Alerta de no movimiento | `NMO1,(min)M,(0/1)` / `NMOO` | Sensores |
| Ubicación actual | `loc` | Inicio |
| Estado de batería | `Battery` | Inicio |
| Configuración actual | `Status` | Inicio |
| Hacer sonar ("acá estoy") | `Findme` | Inicio |
| Escucha remota | `LT1` / `LTO` | Audio |
| Volumen del timbre | `$rt(0-100)$` | Audio |
| Volumen del micrófono | `micvolume(0-15)` | Audio |
| Zona horaria | `TZ(offset)` | Sistema |
| Alerta de batería baja | `Low1,(porcentaje)` | Sistema |

## 🚀 Empezar

### Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) 3.24+ (canal stable)
- Android SDK 34 (lo instala Android Studio)
- Un teléfono con **Android 6.0 (API 23) o superior** y SIM activa
- Un rastreador EV07BG o BX con chip con crédito/plan para SMS

### Compilar e instalar

```bash
git clone https://github.com/mariano9478/sms_tracker.git
cd sms_tracker
flutter pub get
flutter run                # con el teléfono conectado por USB
# o bien:
flutter build apk          # genera build/app/outputs/flutter-apk/app-release.apk
```

### Primeros pasos en la app

1. **Onboarding**: otorgá los permisos de SMS y cargá el número del chip del
   rastreador.
2. **Registrá tu teléfono** en el rastreador desde *Comandos → Contactos SOS*
   (idealmente en la posición 1). ⚠️ El dispositivo **solo procesa comandos
   de números registrados** como contacto de emergencia.
3. Desde *Inicio*, tocá **Batería** o **Ubicación** para verificar que el
   rastreador responde. La respuesta llega por SMS en unos segundos y la app
   la interpreta automáticamente.

## 🏗️ Arquitectura

**Cero plugins de terceros.** Todo el acceso a SMS, preferencias y apertura
de URLs se implementa con canales de plataforma propios en Kotlin, lo que
evita depender de plugins abandonados y mantiene el build simple:

```
lib/
├── main.dart                      # Tema Material 3 + routing inicial
└── src/
    ├── app_state.dart             # Estado central (ChangeNotifier)
    ├── command_catalog.dart       # Genera el texto exacto de cada comando
    ├── response_parser.dart       # Interpreta las respuestas del rastreador
    ├── models.dart                # SmsRecord, SosContact, TrackerLocation
    ├── sms_channel.dart           # Puente Dart ↔ Kotlin
    └── screens/                   # Inicio, Comandos, Mensajes, Ajustes…
        └── sheets/                # Formularios de cada comando

android/app/src/main/kotlin/.../
├── MainActivity.kt
│   ├── MethodChannel sms_tracker/methods    # sendSms, queryInbox, permisos,
│   │                                        # getPref/setPref, openUrl
│   └── EventChannel  sms_tracker/incoming   # SMS entrantes en vivo
└── SmsReceiver.kt                           # notificaciones con la app
                                             # cerrada (receiver del manifest)
```

Detalles de diseño:

- La bandeja de entrada del sistema es la **fuente de verdad** de los
  mensajes recibidos; se filtra por los últimos dígitos del número del
  rastreador para no mezclar los SMS personales del usuario.
- Los comandos enviados se registran en un log local (los SMS enviados por
  API no quedan en el historial del sistema).
- `command_catalog.dart` y `response_parser.dart` son **Dart puro**, sin
  dependencias de Flutter, y están cubiertos por tests.

## 🧪 Tests

```bash
flutter test
```

Verifican que cada comando generado coincide carácter por carácter con la
guía oficial y que el parser extrae correctamente batería, ubicación y
contactos de respuestas reales.

## 🔐 Permisos y privacidad

La app pide `SEND_SMS`, `RECEIVE_SMS` y `READ_SMS` (imprescindibles para
operar el rastreador), `POST_NOTIFICATIONS` (avisos de respuestas en
Android 13+) e `INTERNET` (solo para descargar los tiles del mapa de
OpenStreetMap).

- **Tus datos no salen del teléfono**: no hay servidores propios ni
  analytics. La única red que usa la app es la descarga de imágenes de mapa
  de OpenStreetMap y la resolución del link de ubicación que envía el
  propio rastreador (redirige a Google Maps).
- Cada comando es un SMS común: tu plan puede cobrarlo.
- La escucha remota debe usarse de forma responsable y con consentimiento de
  quien porta el dispositivo.

## 🛠️ Solución de problemas

| Problema | Qué probar |
| :--- | :--- |
| El rastreador no responde a ningún comando | Verificá que tu número esté registrado como contacto SOS y que el chip del rastreador tenga crédito. |
| No responde a los comandos de registro (`A1,1,1,…`) | Envialos desde otro teléfono y pedí a tu compañía desactivar el contestador automático (casilla de voz) de las líneas involucradas. |
| No aparecen las respuestas en la app | Confirmá los permisos de SMS en Ajustes y que el número configurado sea exactamente el del chip del rastreador. |
| La ubicación no se muestra en el mapa | Algunas respuestas traen solo coordenadas; tocá "Abrir en el mapa" en el mensaje dentro de la pestaña Mensajes. |

## 🗺️ Roadmap

- [x] Notificaciones al recibir respuestas del rastreador (incluso con la
      app cerrada)
- [x] Mapa integrado con la última ubicación conocida
- [ ] Rol de "app de SMS predeterminada" para ocultar los mensajes del
      rastreador de la bandeja del sistema
- [ ] Soporte multi-dispositivo (varios rastreadores)
- [ ] Historial de recorridos sobre el mapa

## 🤝 Contribuir

Los issues y pull requests son bienvenidos. Si tenés un EV07BG/BX y el
formato de alguna respuesta no se interpreta bien, abrí un issue con el
texto del SMS (ocultando números personales) para mejorar el parser.

## ⚠️ Descargo de responsabilidad

Proyecto independiente, sin afiliación con los fabricantes de los
dispositivos EV07BG/BX ni con sus distribuidores. Los comandos provienen de
la guía de usuario pública de los dispositivos; verificá el comportamiento
con tu unidad antes de confiar en ella para situaciones de emergencia.

## 📄 Licencia

Distribuido bajo licencia [MIT](LICENSE).
