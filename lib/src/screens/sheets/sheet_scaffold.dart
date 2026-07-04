import 'package:flutter/material.dart';

/// Estructura común de los formularios que arman un comando SMS:
/// título, descripción, campos, vista previa del comando y botón enviar.
class CommandSheetScaffold extends StatelessWidget {
  const CommandSheetScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    required this.commandPreview,
    required this.onSend,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String description;
  final List<Widget> children;

  /// Texto exacto del SMS que se va a enviar (se muestra al usuario).
  final String commandPreview;
  final VoidCallback onSend;

  /// Acción secundaria opcional (por ej. "Desactivar").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.sms_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se enviará: $commandPreview',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              label: const Text('Enviar al rastreador'),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
