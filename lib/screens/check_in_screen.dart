import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/safe_walk_controller.dart';
import '../theme.dart';

/// The last chance to stop an overdue Safe Walk from turning into an SOS.
class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walk = SafeWalkController.instance;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: walk,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.shield, color: Colors.white, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you OK?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'SOS will be sent in ${walk.remaining.inSeconds} seconds.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: walk.finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      minimumSize: const Size(double.infinity, 64),
                    ),
                    child: const Text("I'm safe", style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => walk.extend(const Duration(minutes: 10)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    child: const Text('I need 10 more minutes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
