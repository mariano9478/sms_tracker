import 'package:flutter/material.dart';

import '../app_state.dart';
import '../command_catalog.dart';
import '../models.dart';
import 'home_shell.dart';

/// Administración de los contactos de emergencia (SOS) del rastreador.
/// Hay 10 posiciones. Cada cambio se envía por SMS y se guarda una copia
/// local para mostrar el estado conocido.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contactos SOS'),
            actions: [
              IconButton(
                tooltip: 'Consultar contactos al rastreador (A?)',
                icon: const Icon(Icons.sync),
                onPressed: () => sendCommandWithFeedback(
                  context,
                  state,
                  TrackerCommands.viewContacts,
                  successMessage:
                      'Consulta enviada. El rastreador responderá con la lista.',
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ante una emergencia (botón SOS, caída, etc.) el rastreador '
                  'avisa a estos números en orden. Es obligatorio configurar '
                  'al menos uno, y conviene que el primero sea este teléfono.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (var slot = 1; slot <= 10; slot++)
                _ContactTile(
                  state: state,
                  slot: slot,
                  contact: _contactAt(slot),
                ),
            ],
          ),
        );
      },
    );
  }

  SosContact? _contactAt(int slot) {
    for (final c in state.contacts) {
      if (c.slot == slot) return c;
    }
    return null;
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.state,
    required this.slot,
    required this.contact,
  });

  final AppState state;
  final int slot;
  final SosContact? contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = contact != null;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: configured
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text('$slot'),
      ),
      title: Text(configured ? contact!.number : 'Posición $slot (vacía)'),
      subtitle: configured
          ? Text(
              [
                if (contact!.notifyBySms) 'SMS',
                if (contact!.notifyByCall) 'Llamada',
                if (!contact!.notifyBySms && !contact!.notifyByCall)
                  'Sin avisos',
              ].join(' + '),
            )
          : const Text('Tocá para agregar un número de emergencia'),
      trailing: configured
          ? IconButton(
              tooltip: 'Eliminar del rastreador',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            )
          : const Icon(Icons.add),
      onTap: () => _editContact(context),
    );
  }

  Future<void> _editContact(BuildContext context) async {
    final result = await showDialog<SosContact>(
      context: context,
      builder: (context) => _ContactDialog(slot: slot, existing: contact),
    );
    if (result == null || !context.mounted) return;
    final command = TrackerCommands.addContact(
      slot: result.slot,
      sms: result.notifyBySms,
      call: result.notifyByCall,
      number: result.number,
    );
    final error = await state.sendCommand(command);
    if (error == null) {
      await state.saveContactLocally(result);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Contacto $slot enviado al rastreador ($command). '
                  'Esperá el SMS de confirmación.',
        ),
        backgroundColor:
            error == null ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar contacto $slot'),
        content: Text(
          'Se enviará "${TrackerCommands.removeContact(slot)}" para borrar '
          'el número ${contact!.number} del rastreador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error =
        await state.sendCommand(TrackerCommands.removeContact(slot));
    if (error == null) {
      await state.removeContactLocally(slot);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Contacto $slot eliminado del rastreador.'),
        backgroundColor:
            error == null ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.slot, this.existing});

  final int slot;
  final SosContact? existing;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController _numberController;
  late bool _sms;
  late bool _call;

  @override
  void initState() {
    super.initState();
    _numberController =
        TextEditingController(text: widget.existing?.number ?? '');
    _sms = widget.existing?.notifyBySms ?? true;
    _call = widget.existing?.notifyByCall ?? true;
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Contacto de emergencia ${widget.slot}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Número de teléfono',
              hintText: 'Ej: 1138889888',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisar por SMS'),
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisar con llamada'),
            value: _call,
            onChanged: (v) => setState(() => _call = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final digits =
                _numberController.text.replaceAll(RegExp(r'[^\d+]'), '');
            if (digits.replaceAll('+', '').length < 6) return;
            Navigator.pop(
              context,
              SosContact(
                slot: widget.slot,
                number: digits,
                notifyBySms: _sms,
                notifyByCall: _call,
              ),
            );
          },
          child: const Text('Guardar y enviar'),
        ),
      ],
    );
  }
}
