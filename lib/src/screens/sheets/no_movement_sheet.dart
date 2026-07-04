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
  String _unit = 'M';
  bool _call = true;

  static const _unitLabels = {
    'S': 'segundos (máx. 36000)',
    'M': 'minutos (máx. 600)',
    'H': 'horas (máx. 10)',
  };
  static const _unitMax = {'S': 36000, 'M': 600, 'H': 10};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _amount {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < 1) return 80;
    return v.clamp(1, _unitMax[_unit]!);
  }

  @override
  Widget build(BuildContext context) {
    final command =
        TrackerCommands.noMovement(amount: _amount, unit: _unit, call: _call);
    return CommandSheetScaffold(
      title: 'Alerta de no movimiento',
      description:
          'Si el dispositivo no registra movimiento durante el tiempo '
          'indicado, avisa a los contactos de emergencia.',
      commandPreview: command,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tiempo',
                  hintText: 'Ej: 80',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unidad',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in _unitLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) => setState(() => _unit = v ?? 'M'),
              ),
            ),
          ],
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
      secondaryLabel: 'Desactivar alerta (NMO0)',
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
