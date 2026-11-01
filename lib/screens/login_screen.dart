import 'package:flutter/material.dart';
import '../app_info.dart';
import '../models/incident.dart';
import '../services/auth_service.dart';
import '../services/emergency_controller.dart';
import '../services/sos_service.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';
import 'home_screen.dart';

/// Sign up on first use, log in afterwards. Being logged out must never stand
/// between the user and help, so the SOS is available here too.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _signingUp = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chooseMode();
  }

  Future<void> _chooseMode() async {
    final hasAccount = await _auth.hasAccount();
    if (mounted) setState(() => _signingUp = !hasAccount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final bool success;
    if (_signingUp) {
      await _auth.signUp(
        name: _nameController.text.trim(),
        phone: phone,
        password: password,
      );
      success = true;
    } else {
      success = await _auth.logIn(phone: phone, password: password);
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (!success) {
      setState(() => _error = 'Phone number or password is incorrect.');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _forgotPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your account?'),
        content: const Text(
          'Your password is stored only on this phone, so it can\'t be '
          'recovered. Set a new one: your contacts and settings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auth.resetAccount();
    if (!mounted) return;
    setState(() {
      _signingUp = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_moon,
                        color: Colors.white, size: 46),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    appName,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _signingUp
                        ? 'Create your account in a few seconds.'
                        : 'Stay safe. Stay connected.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 28),
                  if (_signingUp) ...[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        helperText: 'Your contacts see this in SOS alerts',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'Enter a valid phone number'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (_signingUp && v.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.sosRed),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_signingUp ? 'Create account' : 'Login'),
                  ),
                  const SizedBox(height: 8),
                  if (!_signingUp)
                    TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  // Logged out or not, help must stay one tap away.
                  const SizedBox(height: 8),
                  HoldButton(
                    size: 96,
                    color: AppColors.sosRed,
                    semanticLabel: 'Start SOS countdown',
                    onConfirmed: () => EmergencyController.instance
                        .startCountdown(IncidentTrigger.button),
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('Hold for SOS'), style: TextStyle(color: muted)),
                  TextButton.icon(
                    onPressed: () => callNumber('112'),
                    icon: const Icon(Icons.call, color: AppColors.sosRed),
                    label: const Text(
                      'Emergency? Call 112',
                      style: TextStyle(color: AppColors.sosRed),
                    ),
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
