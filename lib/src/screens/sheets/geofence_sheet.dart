import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../command_catalog.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

class GeofenceSheet extends StatefulWidget {
  const GeofenceSheet({super.key, required this.state});

  final AppState state;

  @override
  State<GeofenceSheet> createState() => _GeofenceSheetState();
}

class _GeofenceSheetState extends State<GeofenceSheet> {
  final _controller = TextEditingController(text: '100');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _meters {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < 1) return 100;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final command = TrackerCommands.geofence(meters: _meters);
    return CommandSheetScaffold(
      title: 'Cerco virtual',
      description:
          'El rastreador avisa si se aleja más de la distancia indicada '
          'desde su posición actual. Para cambiar el radio, volvé a enviar '
          'el comando con otro valor.',
      commandPreview: command,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Radio en metros',
            hintText: 'Ej: 100',
            suffixText: 'm',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          command,
          successMessage: 'Cerco virtual de $_meters m configurado.',
        );
      },
    );
  }
}
