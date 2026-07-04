import 'package:flutter/material.dart';

import '../app_state.dart';

/// Ajustes: número/nombre del rastreador, permisos y ayuda.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.sim_card_outlined),
            title: const Text('Número del rastreador'),
            subtitle: Text(state.trackerNumber ?? 'Sin configurar'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTracker(context),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Nombre'),
            subtitle: Text(state.trackerName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTracker(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              state.permissionsGranted
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: state.permissionsGranted
                  ? Colors.green
                  : theme.colorScheme.error,
            ),
            title: const Text('Permisos de SMS'),
            subtitle: Text(
              state.permissionsGranted
                  ? 'Otorgados: la app puede enviar y leer SMS.'
                  : 'Pendientes: tocá para otorgarlos.',
            ),
            onTap: state.permissionsGranted
                ? null
                : () => state.requestPermissions(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Cómo funciona'),
            subtitle: const Text(
                'La app se comunica con el rastreador por SMS comunes.'),
            onTap: () => _showHelp(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Referencia de comandos'),
            subtitle:
                const Text('Lista completa de los comandos que usa la app.'),
            onTap: () => _showCommandReference(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text(
              'Rastreador SOS v1.0 · Compatible con dispositivos '
              'EV07BG (2G) y BX (4G) con firmware DS1/DS2.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTracker(BuildContext context) async {
    final numberController =
        TextEditingController(text: state.trackerNumber ?? '');
    final nameController = TextEditingController(text: state.trackerName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del rastreador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número del chip',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final digits = numberController.text.trim();
      if (digits.replaceAll(RegExp(r'\D'), '').length >= 6) {
        await state.saveTracker(number: digits, name: nameController.text);
      }
    }
    numberController.dispose();
    nameController.dispose();
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo funciona'),
        content: const SingleChildScrollView(
          child: Text(
            '• La app envía SMS con comandos al número del chip del '
            'rastreador y lee sus respuestas para mostrarte todo en '
            'pantallas simples.\n\n'
            '• El chip del rastreador debe tener crédito/plan para '
            'responder SMS.\n\n'
            '• El rastreador solo acepta comandos de números registrados '
            'como contacto de emergencia: registrá este teléfono primero '
            'desde Comandos → Contactos SOS (en la posición 1 idealmente).\n\n'
            '• Si el rastreador no responde a los comandos de registro '
            '(A1,1,1,...), probá enviarlos desde otro teléfono y pedí a tu '
            'compañía desactivar el contestador automático (casilla de voz).\n\n'
            '• Cada envío es un SMS común: tu plan puede cobrarlo.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showCommandReference(BuildContext context) {
    const rows = [
      ('Agregar contacto SOS', 'A1,1,1,número'),
      ('Ver contactos', 'A?'),
      ('Eliminar contacto', 'removeA1'),
      ('Botón lateral → contacto n', 'X1'),
      ('Desactivar botón lateral', 'XO'),
      ('Sensor de caída', 'FL1,5,1'),
      ('Apagar sensor de caída', 'FLO'),
      ('Cerco virtual', 'GE01,1,0,100M'),
      ('Alerta de no movimiento', 'NMO1,80M,1'),
      ('Apagar no movimiento', 'NMOO'),
      ('Ubicación actual', 'loc'),
      ('Estado de batería', 'Battery'),
      ('Configuración actual', 'Status'),
      ('Hacer sonar', 'Findme'),
      ('Escucha remota on/off', 'LT1 / LTO'),
      ('Volumen timbre', r'$rt50$'),
      ('Volumen micrófono', 'micvolume10'),
      ('Zona horaria', 'TZ-03'),
      ('Alerta batería baja', 'Low1,20'),
    ];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referencia de comandos'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.$1)),
                      Text(
                        row.$2,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
