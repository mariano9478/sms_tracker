import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../response_parser.dart';
import '../sms_channel.dart';

/// Conversación con el rastreador: comandos enviados y respuestas
/// recibidas, en formato chat. Incluye envío de comandos manuales.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendManual() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final error = await widget.state.sendCommand(text);
    if (!mounted) return;
    if (error == null) {
      _inputController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.state.records.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.state.refreshInbox(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: records.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: records.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(record: records[index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Comando manual (ej: Status)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendManual(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    icon: const Icon(Icons.send),
                    onPressed: _sendManual,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay mensajes con el rastreador.\n'
              'Enviá una acción rápida desde Inicio o un comando desde '
              'Comandos y la conversación aparecerá acá.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.record});

  final SmsRecord record;

  String _formatDate(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = record.incoming;
    final body = record.body;
    final location =
        incoming ? ResponseParser.parseLocation(body, record.date) : null;
    final isSos = incoming && ResponseParser.isSosAlert(body);

    final bubbleColor = isSos
        ? theme.colorScheme.errorContainer
        : incoming
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer;
    final textColor = isSos
        ? theme.colorScheme.onErrorContainer
        : incoming
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onPrimaryContainer;

    return Align(
      alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(incoming ? 2 : 14),
              bottomRight: Radius.circular(incoming ? 14 : 2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSos) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sos, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Text(
                      'ALERTA DE EMERGENCIA',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(body, style: TextStyle(color: textColor)),
              if (location != null) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => SmsChannel.openUrl(location.openUrl),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Abrir en el mapa',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${incoming ? 'Rastreador' : 'Vos'} · '
                '${_formatDate(record.date)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
