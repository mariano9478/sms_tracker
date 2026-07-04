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
  int _slot = 1;

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
    final command = TrackerCommands.geofence(slot: _slot, meters: _meters);
    return CommandSheetScaffold(
      title: 'Cerco virtual',
      description:
          'El rastreador avisa por SMS si se aleja más de la distancia '
          'indicada. Importante: al configurarlo, el dispositivo debe '
          'estar en el lugar a monitorear (ej: la casa de la persona). '
          'Hay dos cercos independientes.',
      commandPreview: command,
      children: [
        DropdownButtonFormField<int>(
          value: _slot,
          decoration: const InputDecoration(
            labelText: 'Cerco',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Cerco 1 (GEO1)')),
            DropdownMenuItem(value: 2, child: Text('Cerco 2 (GEO2)')),
          ],
          onChanged: (v) => setState(() => _slot = v ?? 1),
        ),
        const SizedBox(height: 12),
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
          successMessage:
              'Cerco virtual $_slot de $_meters m configurado.',
        );
      },
    );
  }
}
