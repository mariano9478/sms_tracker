import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class SpeakerVolumeSheet extends StatefulWidget {
  const SpeakerVolumeSheet({super.key, required this.state});

  final AppState state;

  @override
  State<SpeakerVolumeSheet> createState() => _SpeakerVolumeSheetState();
}

class _SpeakerVolumeSheetState extends State<SpeakerVolumeSheet> {
  double _volume = 80;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.speakerVolume(_volume.round());
    return CommandSheetScaffold(
      title: 'Volumen del parlante',
      description:
          'Volumen del parlante en llamadas y avisos de voz (0 a 100). '
          'Valor de fábrica: 80.',
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
          successMessage:
              'Volumen del parlante ajustado a ${_volume.round()}.',
        );
      },
    );
  }
}
