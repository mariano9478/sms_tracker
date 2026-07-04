import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class RingVolumeSheet extends StatefulWidget {
  const RingVolumeSheet({super.key, required this.state});

  final AppState state;

  @override
  State<RingVolumeSheet> createState() => _RingVolumeSheetState();
}

class _RingVolumeSheetState extends State<RingVolumeSheet> {
  double _volume = 50;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.ringVolume(_volume.round());
    return CommandSheetScaffold(
      title: 'Volumen del timbre',
      description: 'Ajusta el volumen del timbre del rastreador (0 a 100).',
      commandPreview: command,
      children: [
        Text('Volumen: ${_volume.round()}'),
        Slider(
          value: _volume,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_volume.round()}',
          onChanged: (v) => setState(() => _volume = v),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage: 'Volumen del timbre ajustado a ${_volume.round()}.',
        );
      },
    );
  }
}
