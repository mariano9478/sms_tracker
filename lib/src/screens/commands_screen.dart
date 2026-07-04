import 'package:flutter/material.dart';

import '../app_state.dart';
import '../command_catalog.dart';
import 'contacts_screen.dart';
import 'home_shell.dart';
import 'sheets/fall_sensor_sheet.dart';
import 'sheets/geofence_sheet.dart';
import 'sheets/low_battery_sheet.dart';
import 'sheets/mic_volume_sheet.dart';
import 'sheets/no_movement_sheet.dart';
import 'sheets/ring_volume_sheet.dart';
import 'sheets/side_button_sheet.dart';
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
            subtitle: const Text('De 0 a 15.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSheet(context, MicVolumeSheet(state: state)),
          ),
          _SectionHeader(theme: theme, title: 'Sistema'),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Zona horaria'),
            subtitle: const Text('Ej: -03 para Argentina.'),
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
            child: const Text('Desactivar (LTO)'),
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
        successMessage: 'Escucha remota desactivada (LTO).',
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
