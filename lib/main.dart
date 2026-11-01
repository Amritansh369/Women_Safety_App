import 'package:flutter/material.dart';
import 'services/emergency_controller.dart';
import 'services/safe_walk_controller.dart';
import 'services/storage_service.dart';
import 'screens/check_in_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeHerApp());
  EmergencyController.instance.resumeIfActive();
  SafeWalkController.instance.resumeIfActive();
}

class SafeHerApp extends StatelessWidget {
  const SafeHerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      home: const _StartupGate(),
      builder: (context, child) => _SafetyLayer(child: child!),
    );
  }
}

/// Draws the emergency and check-in screens above every route, so that an SOS
/// from a shake or an expired Safe Walk appears wherever the user is, and
/// back-navigation can't lose it.
class _SafetyLayer extends StatelessWidget {
  final Widget child;
  const _SafetyLayer({required this.child});

  @override
  Widget build(BuildContext context) {
    final emergency = EmergencyController.instance;
    final walk = SafeWalkController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([emergency, walk]),
      builder: (context, _) {
        final Widget? layer = emergency.phase != EmergencyPhase.idle
            ? const EmergencyScreen()
            : walk.phase == WalkPhase.checkIn
                ? const CheckInScreen()
                : null;
        return Stack(
          children: [
            ExcludeSemantics(excluding: layer != null, child: child),
            ?layer,
          ],
        );
      },
    );
  }
}

/// Decides whether to show Login or Home based on saved session state.
class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: StorageService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
