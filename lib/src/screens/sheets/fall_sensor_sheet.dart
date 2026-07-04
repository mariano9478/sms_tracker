import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class FallSensorSheet extends StatefulWidget {
  const FallSensorSheet({super.key, required this.state});

  final AppState state;

  @override
  State<FallSensorSheet> createState() => _FallSensorSheetState();
}

class _FallSensorSheetState extends State<FallSensorSheet> {
  double _sensitivity = 5;
  bool _call = true;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.fallSensor(
      sensitivity: _sensitivity.round(),
      call: _call,
    );
    return CommandSheetScaffold(
      title: 'Sensor de caída',
      description:
          'Si detecta una caída, avisa a los contactos de emergencia. '
          'La sensibilidad va de 1 (menos sensible) a 9 (más sensible). '
          'Todos los contactos reciben el SMS de emergencia.',
      commandPreview: command,
      children: [
        Text('Sensibilidad: ${_sensitivity.round()}'),
        Slider(
          value: _sensitivity,
          min: 1,
          max: 9,
          divisions: 8,
          label: '${_sensitivity.round()}',
          onChanged: (v) => setState(() => _sensitivity = v),
        ),
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
          successMessage: 'Sensor de caída configurado.',
        );
      },
      secondaryLabel: 'Desactivar sensor de caída (FLO)',
      onSecondary: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          TrackerCommands.fallSensorOff,
          successMessage: 'Sensor de caída desactivado.',
        );
      },
    );
  }
}
