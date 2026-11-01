import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/readiness_service.dart';
import '../theme.dart';
import 'contacts_screen.dart';

/// A checklist of everything an SOS needs, with a fix for each gap. Permissions
/// are explained and requested here, because the middle of an emergency is the
/// worst moment for a system prompt.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final _service = ReadinessService();
  Readiness? _readiness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final readiness = await _service.check();
    if (mounted) setState(() => _readiness = readiness);
  }

  Future<void> _request(Permission permission) async {
    await _service.request(permission);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _readiness;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Check')),
      body: SafeArea(
        child: state == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    state.allGood
                        ? 'Everything is ready. If you press SOS, it will work.'
                        : 'Finish these steps now so SOS works when you need it.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _Step(
                    icon: Icons.people,
                    title: 'Trusted contacts',
                    done: state.contacts > 0,
                    detail: state.contacts > 0
                        ? '${state.contacts} added. Two or more is safest.'
                        : 'Add the people who should be alerted.',
                    action: 'Add',
                    onFix: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactsScreen(),
                        ),
                      );
                      _refresh();
                    },
                  ),
                  _Step(
                    icon: Icons.location_on,
                    title: 'Location access',
                    done: state.locationGranted,
                    detail: 'So your alert can say where you are.',
                    action: 'Allow',
                    onFix: () => _request(Permission.locationWhenInUse),
                  ),
                  _Step(
                    icon: Icons.gps_fixed,
                    title: 'GPS turned on',
                    done: state.locationServiceOn,
                    detail: 'Without GPS, only your last position can be sent.',
                    action: 'Open',
                    onFix: () async {
                      await Geolocator.openLocationSettings();
                    },
                  ),
                  if (state.canAutoSend)
                    _Step(
                      icon: Icons.sms,
                      title: 'Automatic SMS',
                      done: state.smsGranted,
                      detail: 'Sends alerts by itself, even if you can\'t '
                          'touch your phone. Standard SMS rates apply.',
                      action: 'Allow',
                      onFix: () => _request(Permission.sms),
                    ),
                  _Step(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    done: state.notificationsGranted,
                    detail: 'Shows that protection is running in the background.',
                    action: 'Allow',
                    onFix: () => _request(Permission.notification),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool done;
  final String action;
  final VoidCallback onFix;

  const _Step({
    required this.icon,
    required this.title,
    required this.detail,
    required this.done,
    required this.action,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Icon(
            done ? Icons.check_circle : icon,
            color: done ? AppColors.success : AppColors.warning,
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(detail),
          trailing: done
              ? null
              : FilledButton(onPressed: onFix, child: Text(action)),
        ),
      ),
    );
  }
}
