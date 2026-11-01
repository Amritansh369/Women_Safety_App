import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/shake_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _messageCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _storage.getSettings();
    _messageCtrl.text = settings.customMessage;
    _numberCtrl.text = settings.emergencyNumber;
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _update(AppSettings settings) async {
    setState(() => _settings = settings);
    await _storage.saveSettings(settings);
    await ShakeService.instance.sync();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Settings')),
      body: SafeArea(
        child: settings == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _Heading('When SOS starts'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cancel countdown'),
                    subtitle: const Text('Time to cancel a false alarm'),
                    trailing: DropdownButton<int>(
                      value: settings.countdownSeconds,
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 sec')),
                        DropdownMenuItem(value: 5, child: Text('5 sec')),
                        DropdownMenuItem(value: 10, child: Text('10 sec')),
                      ],
                      onChanged: (value) =>
                          _update(settings.copyWith(countdownSeconds: value)),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Location updates'),
                    subtitle: const Text('Each update is one or two SMS'),
                    trailing: DropdownButton<int>(
                      value: settings.updateIntervalMinutes,
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 min')),
                        DropdownMenuItem(value: 5, child: Text('5 min')),
                        DropdownMenuItem(value: 10, child: Text('10 min')),
                      ],
                      onChanged: (value) => _update(
                        settings.copyWith(updateIntervalMinutes: value),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sound siren automatically'),
                    subtitle: const Text(
                      'Turn off if a loud alarm could put you at risk.',
                    ),
                    value: settings.sirenOnSos,
                    onChanged: (value) =>
                        _update(settings.copyWith(sirenOnSos: value)),
                  ),
                  const SizedBox(height: 12),
                  const _Heading('Hands-free'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shake to start SOS'),
                    subtitle: const Text(
                      'Shake hard four times. The countdown still lets you cancel.',
                    ),
                    value: settings.shakeEnabled,
                    onChanged: (value) =>
                        _update(settings.copyWith(shakeEnabled: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Guardian mode'),
                    subtitle: const Text(
                      'Shake also works with the screen off. Uses more battery '
                      'and shows a notification while it runs.',
                    ),
                    value: settings.shakeEnabled && settings.guardianMode,
                    onChanged: settings.shakeEnabled
                        ? (value) =>
                            _update(settings.copyWith(guardianMode: value))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  const _Heading('Your alert'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 2,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Custom message (optional)',
                      hintText: 'e.g. Call me, I am being followed.',
                    ),
                    onChanged: (value) =>
                        _update(settings.copyWith(customMessage: value)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _numberCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency number',
                      helperText: '112 works across India and the EU.',
                    ),
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        _update(settings.copyWith(emergencyNumber: value.trim()));
                      }
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
