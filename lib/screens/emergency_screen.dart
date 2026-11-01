import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/incident.dart';
import '../services/emergency_controller.dart';
import '../services/sos_service.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';
import '../widgets/live_map.dart';

/// Full-screen SOS: the cancellable countdown, then the live status of the
/// alert. Shown by the safety layer in main.dart rather than pushed as a route.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = EmergencyController.instance;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => controller.phase == EmergencyPhase.countdown
            ? _Countdown(controller: controller)
            : _Active(controller: controller),
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  final EmergencyController controller;
  const _Countdown({required this.controller});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  @override
  void didUpdateWidget(_Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.sosRed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'Sending SOS in',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${controller.secondsLeft}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your location will go to your trusted contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: controller.cancelCountdown,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.sosRed,
                  minimumSize: const Size(double.infinity, 64),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: controller.sendNowDuringCountdown,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Send now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Active extends StatelessWidget {
  final EmergencyController controller;
  const _Active({required this.controller});

  @override
  Widget build(BuildContext context) {
    final incident = controller.incident;
    final fix = controller.fix;
    return Scaffold(
      backgroundColor: AppColors.sosRedDark,
      body: SafeArea(
        child: incident == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Headline(controller: controller, incident: incident),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: () => callNumber(controller.emergencyNumber),
                      icon: const Icon(Icons.call, size: 26),
                      label: Text(
                        'Call ${controller.emergencyNumber}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.sosRedDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DarkButton(
                          icon: controller.sirenOn
                              ? Icons.volume_off
                              : Icons.campaign,
                          label: controller.sirenOn ? 'Stop siren' : 'Siren',
                          onPressed: controller.toggleSiren,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DarkButton(
                          icon: Icons.near_me,
                          label: 'Send location',
                          onPressed: () => _sendLocation(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (fix != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(height: 180, child: LiveMap(fix: fix)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _StatusCard(controller: controller, incident: incident),
                  const SizedBox(height: 28),
                  Center(
                    child: HoldButton(
                      size: 132,
                      color: AppColors.success,
                      semanticLabel: "I'm safe. End SOS and tell my contacts",
                      onConfirmed: controller.markSafe,
                      child: const Text(
                        "HOLD:\nI'M SAFE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Future<void> _sendLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final reached = controller.incident?.countWhere(AlertStatus.sent) ?? 0;
    final fix = controller.fix;
    if (reached > 0) {
      await controller.sendUpdate();
      messenger.showSnackBar(const SnackBar(content: Text('Update sent')));
    } else if (fix != null) {
      await launchUrl(
        Uri.parse(fix.mapsLink),
        mode: LaunchMode.externalApplication,
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Still waiting for a GPS fix')),
      );
    }
  }
}

class _Headline extends StatelessWidget {
  final EmergencyController controller;
  final Incident incident;
  const _Headline({required this.controller, required this.incident});

  @override
  Widget build(BuildContext context) {
    final sent = incident.countWhere(AlertStatus.sent);
    final composer = incident.countWhere(AlertStatus.composer);
    final total = incident.alerts.length;
    final String title;
    final String subtitle;
    if (total == 0) {
      title = 'No contacts to alert';
      subtitle = 'Call ${controller.emergencyNumber} now.';
    } else if (controller.dispatching) {
      title = 'Sending your SOS...';
      subtitle = 'Getting your location and alerting your contacts.';
    } else if (composer > 0) {
      title = 'Press send in your messages app';
      subtitle = 'The alert is written but has NOT been sent yet.';
    } else if (sent == 0) {
      title = 'SOS not sent yet';
      subtitle = 'No signal? Retrying automatically. '
          'Calling ${controller.emergencyNumber} may still work.';
    } else {
      title = 'SOS sent to $sent of $total';
      subtitle = "Location updates will continue until you're safe.";
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _DarkButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final EmergencyController controller;
  final Incident incident;
  const _StatusCard({required this.controller, required this.incident});

  @override
  Widget build(BuildContext context) {
    final failed = incident.countWhere(AlertStatus.failed);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incident.destination.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Heading to ${incident.destination}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          for (final alert in incident.alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _StatusIcon(status: alert.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Text(
                    _statusLabel(alert.status),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => callNumber(alert.phone),
                    icon: const Icon(Icons.call, color: Colors.white),
                    tooltip: null,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
            ),
          if (failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _DarkButton(
                icon: Icons.refresh,
                label: 'Retry $failed failed',
                onPressed: controller.retryFailed,
              ),
            ),
          if (incident.updatesSent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${incident.updatesSent} location update(s) sent',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(AlertStatus status) => switch (status) {
        AlertStatus.pending => 'Waiting',
        AlertStatus.sending => 'Sending',
        AlertStatus.sent => 'Sent',
        AlertStatus.composer => 'Press send',
        AlertStatus.failed => 'Failed',
      };
}

class _StatusIcon extends StatelessWidget {
  final AlertStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AlertStatus.sent =>
        const Icon(Icons.check_circle, color: Colors.white),
      AlertStatus.failed => const Icon(Icons.error, color: Colors.white),
      AlertStatus.composer =>
        const Icon(Icons.touch_app, color: Colors.white),
      _ => const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
    };
  }
}
