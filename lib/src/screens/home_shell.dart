import 'package:flutter/material.dart';

import '../app_state.dart';
import 'commands_screen.dart';
import 'dashboard_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';

/// Contenedor con la barra de navegación inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final screens = [
          DashboardScreen(state: widget.state),
          CommandsScreen(state: widget.state),
          MessagesScreen(state: widget.state),
          SettingsScreen(state: widget.state),
        ];
        return Scaffold(
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
