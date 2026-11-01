import 'package:flutter/material.dart';
import '../services/shake_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final _storage = StorageService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _bloodGroup;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _storage.getProfile();
    _nameCtrl.text = profile['name'] ?? '';
    _phoneCtrl.text = profile['phone'] ?? '';
    final bloodGroup = profile['bloodGroup'] ?? '';
    if (!mounted) return;
    setState(() {
      _bloodGroup = _bloodGroups.contains(bloodGroup) ? bloodGroup : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _storage.saveProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      bloodGroup: _bloodGroup ?? '',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  Future<void> _logout() async {
    await ShakeService.instance.stop();
    await _storage.setLoggedIn(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        _nameCtrl.text.isNotEmpty
                            ? _nameCtrl.text[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full Name',
                        helperText: 'Your contacts see this in SOS alerts',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    decoration: const InputDecoration(
                        labelText: 'Blood Group',
                        helperText: 'Included in SOS alerts for responders',
                        prefixIcon: Icon(Icons.bloodtype_outlined)),
                    items: [
                      for (final group in _bloodGroups)
                        DropdownMenuItem(value: group, child: Text(group)),
                    ],
                    onChanged: (value) => setState(() => _bloodGroup = value),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.tune),
                    label: const Text('Safety Settings'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: AppColors.sosRed),
                    label: const Text('Logout',
                        style: TextStyle(color: AppColors.sosRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.sosRed),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
