import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class NoMovementSheet extends StatefulWidget {
  const NoMovementSheet({super.key, required this.state});

  final AppState state;

  @override
  State<NoMovementSheet> createState() => _NoMovementSheetState();
}

class _NoMovementSheetState extends State<NoMovementSheet> {
  final _controller = TextEditingController(text: '80');
  bool _call = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _minutes {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < 1) return 80;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.noMovement(minutes: _minutes, call: _call);
    return CommandSheetScaffold(
      title: 'Alerta de no movimiento',
      description:
          'Si el dispositivo no registra movimiento durante el tiempo '
          'indicado, avisa a los contactos de emergencia.',
      commandPreview: command,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tiempo sin movimiento',
            hintText: 'Ej: 80',
            suffixText: 'minutos',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Además de avisar por SMS, llamar'),
          value: _call,
          onChanged: (v) => setState(() => _call = v),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage: 'Alerta de no movimiento configurada.',
        );
      },
      secondaryLabel: 'Desactivar alerta (NMOO)',
      onSecondary: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          TrackerCommands.noMovementOff,
          successMessage: 'Alerta de no movimiento desactivada.',
        );
      },
    );
  }
}
