import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../home_shell.dart';
import 'sheet_scaffold.dart';

/// Una opción de un [ChoiceCommandSheet]: etiqueta, descripción y el
/// comando SMS exacto que la aplica.
class CommandChoice {
  const CommandChoice({
    required this.label,
    required this.description,
    required this.command,
  });

  final String label;
  final String description;
  final String command;
}

/// Formulario genérico para configuraciones de opciones excluyentes
/// (on/off): muestra radios y envía el comando de la opción elegida.
class ChoiceCommandSheet extends StatefulWidget {
  const ChoiceCommandSheet({
    super.key,
    required this.state,
    required this.title,
    required this.description,
    required this.choices,
    this.initialIndex = 0,
  });

  final AppState state;
  final String title;
  final String description;
  final List<CommandChoice> choices;
  final int initialIndex;

  @override
  State<ChoiceCommandSheet> createState() => _ChoiceCommandSheetState();
}

class _ChoiceCommandSheetState extends State<ChoiceCommandSheet> {
  late int _selected = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final choice = widget.choices[_selected];
    return CommandSheetScaffold(
      title: widget.title,
      description: widget.description,
      commandPreview: choice.command,
      children: [
        for (var i = 0; i < widget.choices.length; i++)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: i,
            groupValue: _selected,
            title: Text(widget.choices[i].label),
            subtitle: Text(widget.choices[i].description),
            onChanged: (v) => setState(() => _selected = v ?? 0),
          ),
      ],
      onSend: () async {
        Navigator.pop(context);
        await sendCommandWithFeedback(
          context,
          widget.state,
          choice.command,
          successMessage: '${widget.title}: "${choice.label}" enviado '
              '(${choice.command}).',
        );
      },
    );
  }
}
