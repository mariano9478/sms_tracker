import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class SideButtonSheet extends StatefulWidget {
  const SideButtonSheet({super.key, required this.state});

  final AppState state;

  @override
  State<SideButtonSheet> createState() => _SideButtonSheetState();
}

class _SideButtonSheetState extends State<SideButtonSheet> {
  int _slot = 1;

  @override
  Widget build(BuildContext context) {
    return CommandSheetScaffold(
      title: 'Botón lateral',
      description:
          'El botón de llamada rápida marcará al contacto de emergencia elegido.',
      commandPreview: TrackerCommands.sideButton(_slot),
      children: [
        DropdownButtonFormField<int>(
          value: _slot,
          decoration: const InputDecoration(
            labelText: 'Contacto al que llama',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var i = 1; i <= 10; i++)
              DropdownMenuItem(
                value: i,
                child: Text(_labelFor(i)),
              ),
          ],
          onChanged: (v) => setState(() => _slot = v ?? 1),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          TrackerCommands.sideButton(_slot),
          successMessage:
              'Listo: el botón lateral llamará al contacto $_slot.',
        );
      },
      secondaryLabel: 'Desactivar botón lateral (XO)',
      onSecondary: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          TrackerCommands.sideButtonOff,
          successMessage: 'Botón lateral desactivado.',
        );
      },
    );
  }

  String _labelFor(int slot) {
    for (final contact in widget.state.contacts) {
      if (contact.slot == slot) {
        return 'Contacto $slot (${contact.number})';
      }
    }
    return 'Contacto $slot';
  }
}
