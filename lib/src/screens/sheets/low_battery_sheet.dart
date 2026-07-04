import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class LowBatterySheet extends StatefulWidget {
  const LowBatterySheet({super.key, required this.state});

  final AppState state;

  @override
  State<LowBatterySheet> createState() => _LowBatterySheetState();
}

class _LowBatterySheetState extends State<LowBatterySheet> {
  double _percent = 20;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.lowBatteryAlert(_percent.round());
    return CommandSheetScaffold(
      title: 'Alerta de batería baja',
      description:
          'El rastreador envía una alerta automática cuando la batería '
          'llega al porcentaje elegido. Valor de fábrica: 20%.',
      commandPreview: command,
      children: [
        Text('Avisar al llegar a: ${_percent.round()}%'),
        Slider(
          value: _percent,
          min: 5,
          max: 50,
          divisions: 9,
          label: '${_percent.round()}%',
          onChanged: (v) => setState(() => _percent = v),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage:
              'Alerta de batería baja configurada al ${_percent.round()}%.',
        );
      },
    );
  }
}
