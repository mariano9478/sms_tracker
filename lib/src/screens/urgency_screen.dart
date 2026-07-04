import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

/// Plantillas de los avisos manuales de urgencia que un familiar envía a
/// los contactos de emergencia desde su teléfono.
class UrgencyMessages {
  UrgencyMessages._();

  /// Aviso moderado (mitad amarilla): pasó algo, no extremo.
  static String moderate(String name) =>
      '⚠️ AVISO: llamá a $name, algo está pasando. No es una emergencia '
      'extrema, pero comunicate en cuanto puedas. '
      '(Mensaje enviado por un familiar desde la app del rastreador)';

  /// Emergencia (mitad roja).
  static String urgent(String name) =>
      '🚨 URGENTE: hay una emergencia con $name. Llamá o respondé YA. '
      '(Mensaje enviado por un familiar desde la app del rastreador)';
}

/// Pantalla partida al medio que se abre manteniendo apretado el botón
/// rojo de Inicio: arriba (amarillo) el aviso moderado, abajo (rojo) la
/// emergencia. MANTENIENDO APRETADA una mitad se envía el SMS
/// automáticamente a todos los contactos de emergencia (el toque corto
/// solo muestra la ayuda, para evitar envíos accidentales).
class UrgencyScreen extends StatefulWidget {
  const UrgencyScreen({super.key, required this.state});

  final AppState state;

  @override
  State<UrgencyScreen> createState() => _UrgencyScreenState();
}

class _UrgencyScreenState extends State<UrgencyScreen> {
  bool _sending = false;

  Future<void> _dispatch(String message) async {
    if (_sending) return;
    final state = widget.state;
    final numbers = state.contacts.map((c) => c.number).toList();
    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay contactos de emergencia guardados. Sincronizalos desde '
            'Comandos → Contactos SOS (botón A?).',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _sending = true);
    final sent = await state.sendUrgencyMessage(
      numbers: numbers,
      message: message,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    // Referencias antes de cerrar la pantalla.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          sent > 0
              ? 'Aviso enviado por SMS a $sent contacto${sent == 1 ? '' : 's'} '
                  'de emergencia.'
              : 'No se pudo enviar el aviso. Revisá los permisos de SMS.',
        ),
        backgroundColor: sent > 0 ? null : errorColor,
      ),
    );
  }

  void _showHoldHint() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Mantené APRETADA la mitad para enviar el aviso.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.state.trackerName;
    final contactCount = widget.state.contacts.length;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _UrgencyHalf(
                  color: const Color(0xFFF9A825),
                  onColor: Colors.black87,
                  icon: Icons.warning_amber_rounded,
                  title: 'ALGO ESTÁ PASANDO',
                  quote: '"Llamá a $name, algo está pasando."',
                  subtitle: 'Aviso moderado, no extremo.\nMANTENÉ APRETADO '
                      'para enviarlo por SMS a $contactCount contacto'
                      '${contactCount == 1 ? '' : 's'}.',
                  onLongPress: () =>
                      _dispatch(UrgencyMessages.moderate(name)),
                  onTap: _showHoldHint,
                ),
              ),
              Expanded(
                child: _UrgencyHalf(
                  color: const Color(0xFFC62828),
                  onColor: Colors.white,
                  icon: Icons.sos,
                  title: 'URGENTE',
                  quote: '"Hay una emergencia con $name."',
                  subtitle: 'Emergencia.\nMANTENÉ APRETADO para enviarlo '
                      'por SMS a $contactCount contacto'
                      '${contactCount == 1 ? '' : 's'}.',
                  onLongPress: () => _dispatch(UrgencyMessages.urgent(name)),
                  onTap: _showHoldHint,
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (_sending)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Enviando SMS a los contactos…',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UrgencyHalf extends StatelessWidget {
  const _UrgencyHalf({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.quote,
    required this.subtitle,
    required this.onLongPress,
    required this.onTap,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
  final String title;
  final String quote;
  final String subtitle;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: onColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                quote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: onColor.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
