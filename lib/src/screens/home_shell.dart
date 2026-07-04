import 'package:flutter/material.dart';

import '../app_state.dart';
import 'commands_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';
import 'sos_alert_overlay.dart';

/// Contenedor con la barra de navegación inferior. También atiende los
/// pedidos de vista ([AppState.viewRequest]) que generan las
/// notificaciones al ser tocadas.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _viewToIndex = {
    'home': 0,
    'map': 1,
    'commands': 2,
    'messages': 3,
    'settings': 4,
  };

  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.state.viewRequest.addListener(_onViewRequest);
    // Puede haber quedado un pedido pendiente de antes de montar la shell
    // (app abierta desde una notificación).
    WidgetsBinding.instance.addPostFrameCallback((_) => _onViewRequest());
  }

  @override
  void dispose() {
    widget.state.viewRequest.removeListener(_onViewRequest);
    super.dispose();
  }

  void _onViewRequest() {
    final view = widget.state.viewRequest.value;
    if (view == null) return;
    final target = _viewToIndex[view];
    widget.state.viewRequest.value = null;
    if (target != null && mounted && target != _index) {
      setState(() => _index = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final screens = [
          DashboardScreen(state: widget.state),
          MapScreen(state: widget.state),
          CommandsScreen(state: widget.state),
          MessagesScreen(state: widget.state),
          SettingsScreen(state: widget.state),
        ];
        final shell = Scaffold(
          body: IndexedStack(index: _index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Mapa',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Comandos',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Mensajes',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        );
        // La alerta SOS se dibuja por encima de TODA la app hasta que el
        // usuario la descarte.
        return Stack(
          children: [
            shell,
            if (widget.state.activeSosRecord != null)
              SosAlertOverlay(state: widget.state),
          ],
        );
      },
    );
  }
}

/// Envía [command] y muestra el resultado en un SnackBar.
Future<void> sendCommandWithFeedback(
  BuildContext context,
  AppState state,
  String command, {
  String? successMessage,
}) async {
  final error = await state.sendCommand(command);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error ?? successMessage ?? 'Comando enviado: $command',
      ),
      backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
    ),
  );
}
