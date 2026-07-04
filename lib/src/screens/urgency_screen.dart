import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

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
/// emergencia. Tocar una mitad abre la confirmación y el envío a los
/// contactos de emergencia por SMS o WhatsApp.
class UrgencyScreen extends StatelessWidget {
  const UrgencyScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final name = state.trackerName;
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
                  subtitle:
                      'Aviso moderado, no extremo. Tocá para enviarlo a '
                      'los contactos de emergencia.',
                  onTap: () => _openSendSheet(
                    context,
                    title: 'Aviso: algo está pasando',
                    color: const Color(0xFFF9A825),
                    message: UrgencyMessages.moderate(name),
                  ),
                ),
              ),
              Expanded(
                child: _UrgencyHalf(
                  color: const Color(0xFFC62828),
                  onColor: Colors.white,
                  icon: Icons.sos,
                  title: 'URGENTE',
                  quote: '"Hay una emergencia con $name."',
                  subtitle:
                      'Emergencia. Tocá para enviarlo a los contactos de '
                      'emergencia.',
                  onTap: () => _openSendSheet(
                    context,
                    title: 'URGENTE: hay una emergencia',
                    color: const Color(0xFFC62828),
                    message: UrgencyMessages.urgent(name),
                  ),
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
        ],
      ),
    );
  }

  void _openSendSheet(
    BuildContext context, {
    required String title,
    required Color color,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _SendUrgencySheet(
          state: state,
          title: title,
          color: color,
          initialMessage: message,
        ),
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
    required this.onTap,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
  final String title;
  final String quote;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
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

/// Confirmación y envío: mensaje editable, contactos con casillas,
/// envío masivo por SMS y acceso directo a WhatsApp por contacto.
class _SendUrgencySheet extends StatefulWidget {
  const _SendUrgencySheet({
    required this.state,
    required this.title,
    required this.color,
    required this.initialMessage,
  });

  final AppState state;
  final String title;
  final Color color;
  final String initialMessage;

  @override
  State<_SendUrgencySheet> createState() => _SendUrgencySheetState();
}

class _SendUrgencySheetState extends State<_SendUrgencySheet> {
  late final TextEditingController _messageController =
      TextEditingController(text: widget.initialMessage);
  late final Map<int, bool> _selected = {
    for (final c in widget.state.contacts) c.slot: true,
  };
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  List<SosContact> get _selectedContacts => widget.state.contacts
      .where((c) => _selected[c.slot] ?? false)
      .toList();

  Future<void> _sendSms() async {
    final targets = _selectedContacts;
    if (targets.isEmpty) return;
    setState(() => _sending = true);
    final sent = await widget.state.sendUrgencyMessage(
      numbers: targets.map((c) => c.number).toList(),
      message: _messageController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    // Referencias antes de cerrar las rutas: el context del sheet deja
    // de estar montado después de los pops.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    navigator.pop(); // cierra el sheet
    navigator.pop(); // cierra la pantalla de urgencia
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent > 0
              ? 'Aviso enviado por SMS a $sent contacto${sent == 1 ? '' : 's'}.'
              : 'No se pudo enviar el aviso. Revisá los permisos de SMS.',
        ),
        backgroundColor: sent > 0 ? null : errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = widget.state.contacts;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: widget.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mensaje (podés editarlo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty) ...[
              Text(
                'No hay contactos de emergencia guardados en la app. '
                'Sincronizalos desde Comandos → Contactos SOS (botón A?) '
                'y volvé a intentar.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ] else ...[
              Text('Enviar a:', style: theme.textTheme.titleSmall),
              for (final contact in contacts)
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected[contact.slot] ?? false,
                        title: Text(contact.number),
                        subtitle: Text('Contacto ${contact.slot}'),
                        onChanged: (v) => setState(
                            () => _selected[contact.slot] = v ?? false),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar por WhatsApp a este contacto',
                      icon: const Icon(Icons.chat),
                      color: const Color(0xFF25D366),
                      onPressed: () => widget.state.openWhatsApp(
                        number: contact.number,
                        message: _messageController.text.trim(),
                      ),
                    ),
                  ],
                ),
              Text(
                'WhatsApp abre el chat con el mensaje escrito (requiere que '
                'el número tenga código de país). El SMS se envía solo.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed:
                    _sending || _selectedContacts.isEmpty ? null : _sendSms,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  'ENVIAR SMS A ${_selectedContacts.length} '
                  'CONTACTO${_selectedContacts.length == 1 ? '' : 'S'}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
