import 'package:flutter/material.dart';

import '../app_state.dart';

/// Primera pantalla: pide el número del chip del rastreador y los
/// permisos de SMS antes de entrar a la app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController(text: 'Mi rastreador');
  bool _saving = false;

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await widget.state.requestPermissions();
    await widget.state.saveTracker(
      number: _numberController.text,
      name: _nameController.text,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.gps_fixed,
                        size: 72, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Rastreador SOS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configurá y administrá tu dispositivo EV07BG / BX '
                      'sin memorizar comandos: la app envía y lee los SMS '
                      'por vos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _numberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Número del chip del rastreador',
                        hintText: 'Ej: 1138889888',
                        prefixIcon: Icon(Icons.sim_card),
                        border: OutlineInputBorder(),
                        helperText:
                            'Es el número de la SIM que está dentro del dispositivo.',
                      ),
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 6) {
                          return 'Ingresá un número de teléfono válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre (opcional)',
                        hintText: 'Ej: Abuela, Auto, Mochila…',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _continue,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Comenzar'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Se pedirán permisos de SMS: son necesarios para '
                      'enviar comandos al rastreador y leer sus respuestas.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
