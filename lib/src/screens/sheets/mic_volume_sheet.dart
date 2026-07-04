import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class MicVolumeSheet extends StatefulWidget {
  const MicVolumeSheet({super.key, required this.state});

  final AppState state;

  @override
  State<MicVolumeSheet> createState() => _MicVolumeSheetState();
}

class _MicVolumeSheetState extends State<MicVolumeSheet> {
  double _volume = 10;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.micVolume(_volume.round());
    return CommandSheetScaffold(
      title: 'Volumen del micrófono',
      description: 'Ajusta la ganancia del micrófono (0 a 15).',
      commandPreview: command,
      children: [
        Text('Volumen: ${_volume.round()}'),
        Slider(
          value: _volume,
          min: 0,
          max: 15,
          divisions: 15,
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
          successMessage:
              'Volumen del micrófono ajustado a ${_volume.round()}.',
        );
      },
    );
  }
}
