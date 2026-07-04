import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class DeviceNameSheet extends StatefulWidget {
  const DeviceNameSheet({super.key, required this.state});

  final AppState state;

  @override
  State<DeviceNameSheet> createState() => _DeviceNameSheetState();
}

class _DeviceNameSheetState extends State<DeviceNameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.state.trackerName);
  bool _alsoInApp = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name =>
      _controller.text.trim().isEmpty ? 'Mi rastreador' : _controller.text.trim();

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.deviceName(_name);
    return CommandSheetScaffold(
      title: 'Nombre del dispositivo',
      description:
          'El rastreador incluirá este nombre en los SMS que envía, útil '
          'si administrás más de un dispositivo. Ej: "Mamá".',
      commandPreview: command,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Mamá',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar también como nombre en esta app'),
          value: _alsoInApp,
          onChanged: (v) => setState(() => _alsoInApp = v),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        if (_alsoInApp) {
          await widget.state.saveTracker(
            number: widget.state.trackerNumber ?? '',
            name: _name,
          );
        }
        if (!context.mounted) return;
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage: 'Nombre "$_name" enviado al rastreador.',
        );
      },
    );
  }
}
