import 'package:flutter/material.dart';
import '../models/incident.dart';
import '../services/emergency_controller.dart';
import '../services/readiness_service.dart';
import '../services/safe_walk_controller.dart';
import '../services/shake_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';
import 'contacts_screen.dart';
import 'fake_call_screen.dart';
import 'helplines_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'safe_walk_screen.dart';
import 'setup_screen.dart';
import 'tips_screen.dart';
import 'tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _readinessService = ReadinessService();
  final _storage = StorageService();
  Readiness? _readiness;
  String _name = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShakeService.instance.sync();
    _refresh();
    _showSetupOnFirstRun();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user may have changed a permission in system settings while away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final readiness = await _readinessService.check();
    final profile = await _storage.getProfile();
    if (!mounted) return;
    setState(() {
      _readiness = readiness;
      _name = profile['name'] ?? '';
    });
  }

  Future<void> _showSetupOnFirstRun() async {
    if (await _storage.isSetupSeen() || !mounted) return;
    await _storage.setSetupSeen();
    if (!mounted) return;
    await _open(const SetupScreen());
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _name.trim().split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Text(firstName.isEmpty ? 'SafeHer' : 'Hi, $firstName'),
        actions: [
          IconButton(
            tooltip: 'Profile and settings',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _open(const ProfileScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _ReadinessCard(
              readiness: _readiness,
              onTap: () => _open(const SetupScreen()),
            ),
            const _WalkBanner(),
            const SizedBox(height: 28),
            Center(
              child: HoldButton(
                color: AppColors.sosRed,
                semanticLabel: 'Start SOS countdown',
                onConfirmed: () => EmergencyController.instance
                    .startCountdown(IncidentTrigger.button),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'Press and hold',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _FeatureCard(
                  icon: Icons.directions_walk,
                  label: 'Safe Walk',
                  color: AppColors.rose,
                  onTap: () => _open(const SafeWalkScreen()),
                ),
                _FeatureCard(
                  icon: Icons.location_on,
                  label: 'Live Location',
                  color: AppColors.accent,
                  onTap: () => _open(const TrackingScreen()),
                ),
                _FeatureCard(
                  icon: Icons.contact_phone,
                  label: 'Contacts',
                  color: AppColors.primary,
                  onTap: () => _open(const ContactsScreen()),
                ),
                _FeatureCard(
                  icon: Icons.phone_callback,
                  label: 'Fake Call',
                  color: AppColors.success,
                  onTap: () => _open(const FakeCallScreen()),
                ),
                _FeatureCard(
                  icon: Icons.local_police,
                  label: 'Helplines',
                  color: AppColors.sosRed,
                  onTap: () => _open(const HelplinesScreen()),
                ),
                _FeatureCard(
                  icon: Icons.shield,
                  label: 'Safety Tips',
                  color: AppColors.warning,
                  onTap: () => _open(const TipsScreen()),
                ),
                _FeatureCard(
                  icon: Icons.history,
                  label: 'History',
                  color: AppColors.primaryDark,
                  onTap: () => _open(const HistoryScreen()),
                ),
                _FeatureCard(
                  icon: Icons.tune,
                  label: 'Safety Check',
                  color: AppColors.accent,
                  onTap: () => _open(const SetupScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  final Readiness? readiness;
  final VoidCallback onTap;
  const _ReadinessCard({required this.readiness, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = readiness;
    if (state == null) return const SizedBox(height: 72);
    final ok = state.allGood;
    final color = ok ? AppColors.success : AppColors.warning;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(ok ? Icons.verified_user : Icons.gpp_maybe, color: color),
        title: Text(
          ok ? "You're protected" : 'SOS is not fully set up',
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
        subtitle: Text(
          ok
              ? '${state.contacts} trusted contact(s) will be alerted'
              : '${state.missing} step(s) left. Tap to finish.',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Shows the running Safe Walk on Home so it can't be forgotten.
class _WalkBanner extends StatelessWidget {
  const _WalkBanner();

  @override
  Widget build(BuildContext context) {
    final walk = SafeWalkController.instance;
    return ListenableBuilder(
      listenable: walk,
      builder: (context, _) {
        if (walk.phase != WalkPhase.walking) return const SizedBox.shrink();
        final left = walk.remaining;
        final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.directions_walk, color: AppColors.rose),
              title: const Text(
                'Safe Walk active',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${left.inMinutes}:$seconds left to check in'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SafeWalkScreen()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 26, color: dark ? null : color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
