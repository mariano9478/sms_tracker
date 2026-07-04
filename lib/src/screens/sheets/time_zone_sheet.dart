import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class TimeZoneSheet extends StatefulWidget {
  const TimeZoneSheet({super.key, required this.state});

  final AppState state;

  @override
  State<TimeZoneSheet> createState() => _TimeZoneSheetState();
}

class _TimeZoneSheetState extends State<TimeZoneSheet> {
  int _offset = -3;

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.timeZone(_offset);
    return CommandSheetScaffold(
      title: 'Zona horaria',
      description:
          'Define la zona horaria del rastreador para que los reportes '
          'tengan la hora correcta. Argentina: -03.',
      commandPreview: command,
      children: [
        DropdownButtonFormField<int>(
          value: _offset,
          decoration: const InputDecoration(
            labelText: 'Desfase respecto de GMT',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var i = -12; i <= 14; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  i < 0
                      ? 'GMT-${i.abs().toString().padLeft(2, '0')}'
                      : 'GMT+${i.toString().padLeft(2, '0')}',
                ),
              ),
          ],
          onChanged: (v) => setState(() => _offset = v ?? -3),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage: 'Zona horaria configurada ($command).',
        );
      },
    );
  }
}
