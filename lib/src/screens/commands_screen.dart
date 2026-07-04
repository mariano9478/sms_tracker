import 'package:flutter/material.dart';

import '../app_state.dart';
import '../command_catalog.dart';
import 'contacts_screen.dart';
import 'home_shell.dart';
import 'sheets/choice_sheet.dart';
import 'sheets/device_name_sheet.dart';
import 'sheets/fall_sensor_sheet.dart';
import 'sheets/geofence_sheet.dart';
import 'sheets/low_battery_sheet.dart';
import 'sheets/mic_volume_sheet.dart';
import 'sheets/no_movement_sheet.dart';
import 'sheets/ring_volume_sheet.dart';
import 'sheets/side_button_sheet.dart';
import 'sheets/speaker_volume_sheet.dart';
import 'sheets/time_zone_sheet.dart';

/// Todas las funciones del rastreador organizadas por categoría.
/// Cada ítem abre un formulario simple; la app arma y envía el SMS.
class CommandsScreen extends StatelessWidget {
  const CommandsScreen({super.key, required this.state});

  final AppState state;

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: sheet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Comandos')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SectionHeader(theme: theme, title: 'Contactos y botones'),
          ListTile(
            leading: const Icon(Icons.contact_phone_outlined),
            title: const Text('Contactos SOS'),
            subtitle: const Text(
                'Números de emergencia (hasta 10). Obligatorio configurar al menos uno.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactsScreen(state: state),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.radio_button_checked),
            title: const Text('Botón lateral'),
            subtitle:
                const Text('Elegí a qué contacto llama el botón de llamada rápida.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, SideButtonSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.phone_forwarded_outlined),
            title: const Text('Secuencia de llamadas SOS'),
            subtitle: const Text(
                'Qué hace el rastreador cuando un contacto atiende la llamada de emergencia.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(
              context,
              ChoiceCommandSheet(
                state: state,
                title: 'Secuencia de llamadas SOS',
                description:
                    'En una emergencia el rastreador llama a los contactos '
                    'en orden. Definí qué pasa cuando uno atiende (todos '
                    'reciben el SMS de aviso igualmente).',
                initialIndex: 1,
                choices: [
                  CommandChoice(
                    label: 'Seguir llamando al resto',
                    description: 'Valor de fábrica (SCS0).',
                    command: TrackerCommands.callSequence(interrupt: false),
                  ),
                  CommandChoice(
                    label: 'Cortar la secuencia al ser atendido',
                    description: 'Sugerido por el fabricante (SCS1).',
                    command: TrackerCommands.callSequence(interrupt: true),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.call_received_outlined),
            title: const Text('Llamadas entrantes'),
            subtitle: const Text(
                'Aceptar llamadas de cualquiera o solo de los contactos (lista blanca).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(
              context,
              ChoiceCommandSheet(
                state: state,
                title: 'Llamadas entrantes',
                description:
                    'El dispositivo atiende automáticamente después de dos '
                    'rings. Definí quiénes pueden llamarlo.',
                choices: [
                  CommandChoice(
                    label: 'Aceptar todas las llamadas',
                    description: 'Cualquier número puede llamar (callin1).',
                    command: TrackerCommands.callIn(all: true),
                  ),
                  CommandChoice(
                    label: 'Solo contactos de emergencia',
                    description:
                        'Lista blanca: rechaza al resto (callin0).',
                    command: TrackerCommands.callIn(all: false),
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader(theme: theme, title: 'Sensores y alarmas'),
          ListTile(
            leading: const Icon(Icons.personal_injury_outlined),
            title: const Text('Sensor de caída'),
            subtitle: const Text(
                'Detecta caídas y avisa a los contactos. Sensibilidad 1 a 9.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, FallSensorSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.fence_outlined),
            title: const Text('Cerco virtual'),
            subtitle: const Text(
                'Avisa si el dispositivo se aleja más de cierta distancia.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, GeofenceSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility_new_outlined),
            title: const Text('Alerta de no movimiento'),
            subtitle: const Text(
                'Avisa si el dispositivo no se mueve durante cierto tiempo.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, NoMovementSheet(state: state)),
          ),
          _SectionHeader(theme: theme, title: 'Audio y escucha'),
          ListTile(
            leading: const Icon(Icons.hearing_outlined),
            title: const Text('Escucha remota'),
            subtitle: const Text(
                'Micrófono silencioso: escuchá el entorno del dispositivo.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRemoteListenDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up_outlined),
            title: const Text('Volumen del timbre'),
            subtitle: const Text('De 0 a 100.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, RingVolumeSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.mic_none_outlined),
            title: const Text('Volumen del micrófono'),
            subtitle: const Text('De 0 a 15 (fábrica: 8).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, MicVolumeSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.speaker_outlined),
            title: const Text('Volumen del parlante'),
            subtitle: const Text('De 0 a 100 (fábrica: 80).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, SpeakerVolumeSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Parlante en llamadas SOS'),
            subtitle: const Text(
                'Altavoz durante las llamadas de emergencia (sugerido: apagado).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(
              context,
              ChoiceCommandSheet(
                state: state,
                title: 'Parlante en llamadas SOS',
                description:
                    'Define si las llamadas de emergencia usan el altavoz '
                    'del dispositivo.',
                initialIndex: 1,
                choices: [
                  CommandChoice(
                    label: 'Encendido',
                    description: 'sosspeaker1',
                    command: TrackerCommands.sosSpeaker(on: true),
                  ),
                  CommandChoice(
                    label: 'Apagado',
                    description: 'Sugerido por el fabricante (sosspeaker0).',
                    command: TrackerCommands.sosSpeaker(on: false),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voces del dispositivo'),
            subtitle: const Text(
                'Activar o eliminar los avisos de voz de fábrica.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(
              context,
              ChoiceCommandSheet(
                state: state,
                title: 'Voces del dispositivo',
                description:
                    'El rastreador anuncia con voz algunas acciones '
                    '("Llamando al contacto número 1", etc.).',
                choices: [
                  CommandChoice(
                    label: 'Dejar las voces de fábrica',
                    description: 'beep1',
                    command: TrackerCommands.beepVoices(on: true),
                  ),
                  CommandChoice(
                    label: 'Eliminar las voces',
                    description: 'beep0',
                    command: TrackerCommands.beepVoices(on: false),
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader(theme: theme, title: 'Sistema'),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Nombre del dispositivo'),
            subtitle: const Text(
                'El rastreador incluirá el nombre en los SMS que envía.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, DeviceNameSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Zona horaria y hora'),
            subtitle: const Text(
                'La hora se sincroniza sola de la red; acá se corrige la zona (-03 Argentina).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, TimeZoneSheet(state: state)),
          ),
          ListTile(
            leading: const Icon(Icons.battery_alert_outlined),
            title: const Text('Alerta de batería baja'),
            subtitle: const Text(
                'A qué porcentaje avisa el rastreador (de fábrica: 20%).'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, LowBatterySheet(state: state)),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoteListenDialog(BuildContext context) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escucha remota'),
        content: const Text(
          'Activa el micrófono del rastreador en modo silencioso para '
          'escuchar el entorno. Usala de forma responsable y con '
          'consentimiento de quien porta el dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'off'),
            child: const Text('Desactivar (LT0)'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'on'),
            child: const Text('Activar (LT1)'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'on') {
      await sendCommandWithFeedback(
        context,
        state,
        TrackerCommands.remoteListenOn,
        successMessage: 'Escucha remota activada (LT1).',
      );
    } else {
      await sendCommandWithFeedback(
        context,
        state,
        TrackerCommands.remoteListenOff,
        successMessage: 'Escucha remota desactivada (LT0).',
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.theme, required this.title});

  final ThemeData theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
