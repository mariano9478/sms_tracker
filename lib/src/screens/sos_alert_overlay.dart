import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import 'map_screen.dart' show formatDateTime;

/// Alerta de emergencia a pantalla completa: fondo rojo pulsante,
/// vibración periódica y acciones directas. Se muestra encima de toda la
/// app mientras haya un SOS sin descartar ([AppState.activeSosRecord]).
class SosAlertOverlay extends StatefulWidget {
  const SosAlertOverlay({super.key, required this.state});

  final AppState state;

  @override
  State<SosAlertOverlay> createState() => _SosAlertOverlayState();
}

class _SosAlertOverlayState extends State<SosAlertOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    // Vibración recurrente mientras la alerta esté visible.
    _hapticTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => HapticFeedback.heavyImpact(),
    );
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final record = state.activeSosRecord;
    final alarmTime = state.sosAlarmTime;
    final battery = state.batteryPercent;

    final backgroundColor = ColorTween(
      begin: const Color(0xFFB71C1C),
      end: const Color(0xFF7F0000),
    ).animate(_pulse);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Material(
        color: backgroundColor.value,
        child: child,
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: const Icon(Icons.sos, size: 120, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡BOTÓN SOS ACTIVADO!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.trackerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (alarmTime != null &&
                    record != null &&
                    alarmTime.difference(record.date).abs() <=
                        const Duration(hours: 48))
                  _InfoLine(
                    icon: Icons.access_time_filled,
                    text: 'Activado ${formatDateTime(alarmTime)}',
                  )
                else if (record != null)
                  _InfoLine(
                    icon: Icons.access_time_filled,
                    text: 'Recibido ${formatDateTime(record.date)}',
                  ),
                if (battery != null)
                  _InfoLine(
                    icon: Icons.battery_std,
                    text: 'Batería del rastreador: $battery%',
                  ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    minimumSize: const Size(280, 56),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    state.viewRequest.value = 'map';
                    await state.dismissSosAlert();
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('VER EN EL MAPA'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    minimumSize: const Size(280, 56),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => state.callTracker(),
                  icon: const Icon(Icons.call),
                  label: const Text('LLAMAR AL RASTREADOR'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  onPressed: () => state.dismissSosAlert(),
                  child: const Text('Descartar alerta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
