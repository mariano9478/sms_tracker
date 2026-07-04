import 'package:flutter/material.dart';

import 'src/app_state.dart';
import 'src/screens/home_shell.dart';
import 'src/screens/onboarding_screen.dart';

void main() {
  runApp(const SmsTrackerApp());
}

class SmsTrackerApp extends StatefulWidget {
  const SmsTrackerApp({super.key});

  @override
  State<SmsTrackerApp> createState() => _SmsTrackerAppState();
}

class _SmsTrackerAppState extends State<SmsTrackerApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rastreador SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          brightness: Brightness.dark,
        ),
      ),
      home: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          if (!_state.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_state.isConfigured) {
            return OnboardingScreen(state: _state);
          }
          return HomeShell(state: _state);
        },
      ),
    );
  }
}
