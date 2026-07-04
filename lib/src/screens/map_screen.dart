import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../command_catalog.dart';
import '../models.dart';
import 'home_shell.dart';

/// Última ubicación conocida sobre un mapa (tiles de OpenStreetMap, sin
/// plugins). Si el rastreador mandó solo un link (formato smart-locator),
/// se ofrece abrirlo directamente.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final location = state.lastLocation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            tooltip: 'Pedir ubicación al rastreador (loc)',
            icon: const Icon(Icons.my_location),
            onPressed: () => _requestLocation(context),
          ),
        ],
      ),
      body: location == null
          ? _NoLocationView(onRequest: () => _requestLocation(context))
          : location.hasCoordinates
              ? Column(
                  children: [
                    Expanded(
                      child: OsmMapView(
                        latitude: location.latitude!,
                        longitude: location.longitude!,
                      ),
                    ),
                    _LocationInfoBar(state: state, location: location),
                  ],
                )
              : _LinkOnlyView(
                  state: state,
                  location: location,
                  onRequest: () => _requestLocation(context),
                ),
    );
  }

  Future<void> _requestLocation(BuildContext context) {
    return sendCommandWithFeedback(
      context,
      state,
      TrackerCommands.locate,
      successMessage:
          'Ubicación solicitada. Cuando el rastreador responda te llegará '
          'una notificación.',
    );
  }
}

class _NoLocationView extends StatelessWidget {
  const _NoLocationView({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Todavía no hay ninguna ubicación del rastreador.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pedila y en unos segundos llegará la respuesta por SMS; '
              'la app te avisará con una notificación.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.my_location),
              label: const Text('Pedir ubicación'),
            ),
          ],
        ),
      ),
    );
  }
}

/// La respuesta trae la posición como un link (smart-locator) que redirige
/// a Google Maps. La app resuelve esa redirección en segundo plano para
/// mostrar la posición en el mapa integrado: mientras tanto (o si falla)
/// se muestra esta tarjeta.
class _LinkOnlyView extends StatelessWidget {
  const _LinkOnlyView({
    required this.state,
    required this.location,
    required this.onRequest,
  });

  final AppState state;
  final TrackerLocation location;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolving = state.resolvingLocation;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (resolving)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else
                    Icon(Icons.place,
                        size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    resolving
                        ? 'Obteniendo la posición…'
                        : 'Ubicación recibida',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolving
                        ? 'El rastreador envió un link de mapa '
                            '(${formatDateTime(location.reportedAt)}). '
                            'Se están obteniendo las coordenadas para '
                            'mostrarlo acá.'
                        : 'El rastreador envió un link de mapa '
                            '(${formatDateTime(location.reportedAt)}), pero '
                            'no se pudieron obtener las coordenadas '
                            'automáticamente (¿sin internet?). Podés '
                            'reintentar o abrir el link directo.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (location.deviceTimeReliable) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hora reportada por el dispositivo: '
                      '${formatDateTime(location.deviceTime!)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (location.deviceTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ El reloj del rastreador está desincronizado '
                      '(reportó ${formatDateTime(location.deviceTime!)}). '
                      'Se corrige solo cuando el dispositivo obtiene señal '
                      'de red/GPS; verificá la zona horaria en '
                      'Comandos → Zona horaria y hora (TZ-03).',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!resolving) ...[
                    FilledButton.icon(
                      onPressed: () => state.retryResolveLocation(),
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Reintentar mostrar en el mapa'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => state.openMap(),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir link de ubicación'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Pedir ubicación nueva'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationInfoBar extends StatelessWidget {
  const _LocationInfoBar({required this.state, required this.location});

  final AppState state;
  final TrackerLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${location.latitude!.toStringAsFixed(5)}, '
                      '${location.longitude!.toStringAsFixed(5)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'Recibida ${formatDateTime(location.reportedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => state.openMap(),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Google Maps'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDateTime(DateTime date) {
  final now = DateTime.now();
  final sameDay =
      now.year == date.year && now.month == date.month && now.day == date.day;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  if (sameDay) return 'hoy a las $hh:$mm';
  final dd = date.day.toString().padLeft(2, '0');
  final mo = date.month.toString().padLeft(2, '0');
  return 'el $dd/$mo a las $hh:$mm';
}

/// Mapa estático con tiles de OpenStreetMap centrado en un punto, con pin,
/// controles de zoom y atribución. Implementado sin plugins: solo
/// `Image.network` y proyección Web Mercator.
class OsmMapView extends StatefulWidget {
  const OsmMapView({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  static const double _tileSize = 256;
  static const int _minZoom = 3;
  static const int _maxZoom = 19;

  int _zoom = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final tilesPerSide = 1 << _zoom;

        // Proyección Web Mercator: posición global en píxeles.
        final latRad = widget.latitude * math.pi / 180;
        final worldX =
            (widget.longitude + 180) / 360 * tilesPerSide * _tileSize;
        final worldY = (1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            tilesPerSide *
            _tileSize;

        // Esquina superior izquierda del viewport en píxeles globales.
        final originX = worldX - width / 2;
        final originY = worldY - height / 2;

        final txMin = (originX / _tileSize).floor();
        final txMax = ((originX + width) / _tileSize).floor();
        final tyMin = (originY / _tileSize).floor();
        final tyMax = ((originY + height) / _tileSize).floor();

        final tiles = <Widget>[];
        for (var tx = txMin; tx <= txMax; tx++) {
          for (var ty = tyMin; ty <= tyMax; ty++) {
            if (ty < 0 || ty >= tilesPerSide) continue;
            final wrappedX = ((tx % tilesPerSide) + tilesPerSide) % tilesPerSide;
            tiles.add(Positioned(
              left: tx * _tileSize - originX,
              top: ty * _tileSize - originY,
              width: _tileSize,
              height: _tileSize,
              child: Image.network(
                'https://tile.openstreetmap.org/$_zoom/$wrappedX/$ty.png',
                width: _tileSize,
                height: _tileSize,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ));
          }
        }

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: theme.colorScheme.surfaceContainerHighest),
              ),
              ...tiles,
              // Pin: la punta cae exactamente en el centro (la ubicación).
              Positioned(
                left: width / 2 - 24,
                top: height / 2 - 46,
                child: Icon(
                  Icons.location_pin,
                  size: 48,
                  color: theme.colorScheme.error,
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black45),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 28,
                child: Column(
                  children: [
                    IconButton.filled(
                      tooltip: 'Acercar',
                      icon: const Icon(Icons.add),
                      onPressed: _zoom >= _maxZoom
                          ? null
                          : () => setState(() => _zoom++),
                    ),
                    const SizedBox(height: 8),
                    IconButton.filled(
                      tooltip: 'Alejar',
                      icon: const Icon(Icons.remove),
                      onPressed: _zoom <= _minZoom
                          ? null
                          : () => setState(() => _zoom--),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
