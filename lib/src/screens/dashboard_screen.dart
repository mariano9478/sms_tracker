import 'package:flutter/material.dart';

import '../app_state.dart';
import '../command_catalog.dart';
import 'home_shell.dart';
import 'urgency_screen.dart';

/// Pantalla de inicio: estado del rastreador y acciones rápidas.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(state.trackerName),
        actions: [
          IconButton(
            tooltip: 'Actualizar mensajes',
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshInbox(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshInbox,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!state.permissionsGranted) _PermissionsCard(state: state),
            _StatusCard(state: state),
            const SizedBox(height: 16),
            Text('Acciones rápidas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _QuickActions(state: state),
            const SizedBox(height: 16),
            _UrgencyButton(state: state),
            const SizedBox(height: 16),
            _HowItWorksCard(state: state),
            const SizedBox(height: 12),
            _InfoCard(theme: theme),
          ],
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Faltan permisos de SMS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sin ellos la app no puede enviar comandos ni leer las '
              'respuestas del rastreador.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => state.requestPermissions(),
              child: const Text('Otorgar permisos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final AppState state;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final sameDay = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (sameDay) return 'hoy $hh:$mm';
    final dd = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final battery = state.batteryPercent;
    final location = state.lastLocation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.gps_fixed,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.trackerName,
                          style: theme.textTheme.titleMedium),
                      Text(state.trackerNumber ?? '',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  battery == null
                      ? Icons.battery_unknown
                      : battery > 60
                          ? Icons.battery_full
                          : battery > 20
                              ? Icons.battery_4_bar
                              : Icons.battery_alert,
                  color: battery != null && battery <= 20
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    battery == null
                        ? 'Batería: sin datos (tocá "Batería" para consultar)'
                        : 'Batería: $battery% '
                            '(${_formatDate(state.batteryReportedAt!)})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location == null
                        ? 'Ubicación: sin datos (tocá "Ubicación" para pedirla)'
                        : location.hasCoordinates
                            ? 'Última ubicación: ${location.latitude!.toStringAsFixed(5)}, '
                                '${location.longitude!.toStringAsFixed(5)} '
                                '(${_formatDate(location.reportedAt)})'
                            : 'Ubicación recibida ${_formatDate(location.reportedAt)}',
                  ),
                ),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => state.viewRequest.value = 'map',
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en el mapa'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.place,
        label: 'Ubicación',
        command: TrackerCommands.locate,
        message: 'Ubicación solicitada. La respuesta llega por SMS en unos segundos.',
      ),
      (
        icon: Icons.battery_std,
        label: 'Batería',
        command: TrackerCommands.battery,
        message: 'Consulta de batería enviada.',
      ),
      (
        icon: Icons.info_outline,
        label: 'Estado',
        command: TrackerCommands.status,
        message: 'Consulta de configuración enviada.',
      ),
      (
        icon: Icons.notifications_active_outlined,
        label: 'Hacer sonar',
        command: TrackerCommands.findMe,
        message: 'El rastreador va a sonar para que lo encuentres.',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final action in actions)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => sendCommandWithFeedback(
                context,
                state,
                action.command,
                successMessage: action.message,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(action.icon,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón rojo de urgencia manual: manteniéndolo apretado se abre la
/// pantalla partida (aviso moderado / emergencia) para avisar a los
/// contactos de emergencia desde este teléfono.
class _UrgencyButton extends StatelessWidget {
  const _UrgencyButton({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFC62828),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UrgencyScreen(state: state)),
        ),
        onTap: () {
          // El tap corto solo muestra la ayuda: el gesto real es mantener
          // apretado, para evitar aperturas accidentales.
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content:
                  Text('Mantené APRETADO el botón para avisar una urgencia.'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.emergency_share, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'HAY UNA URGENCIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mantené apretado para avisar a los contactos de emergencia',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.touch_app, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aclara que todo pasa por SMS y lista los comandos básicos, cada uno
/// con acceso directo a la app de Mensajes con el texto ya escrito —
/// plan B si algo no se ve reflejado en esta app.
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.state});

  final AppState state;

  static const _basicCommands = [
    (command: 'loc', description: 'Pedir la ubicación actual'),
    (command: 'Battery', description: 'Consultar la batería'),
    (command: 'Status', description: 'Ver la configuración'),
    (command: 'Findme', description: 'Hacerlo sonar para encontrarlo'),
    (command: 'A?', description: 'Ver los contactos de emergencia'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sms_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('¿Cómo funciona?', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Esta app se comunica con el rastreador por SMS comunes: '
              'envía los comandos y lee las respuestas para mostrarte todo '
              'acá. Ante cualquier duda —o si algo no aparece— podés '
              'revisar la conversación directamente en la app de Mensajes '
              'del teléfono.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Comandos básicos (ubicación y urgencias):',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final item in _basicCommands)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => state.openSmsComposer(item.command),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.command,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.description,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => state.openSmsComposer(),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Abrir la app de Mensajes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Importante: el rastreador solo responde a números '
                'registrados como contacto de emergencia. Agregá este '
                'teléfono desde "Comandos → Contactos SOS".',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
