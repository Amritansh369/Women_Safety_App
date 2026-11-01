import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/siren_service.dart';

/// Schedules a convincing incoming call: a polite way out of an uncomfortable
/// situation before it becomes an emergency.
class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  static const _delays = {'Now': 0, '10 sec': 10, '30 sec': 30, '1 min': 60};
  final _nameCtrl = TextEditingController(text: 'Mom');
  int _delay = 10;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _schedule() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Mom' : _nameCtrl.text.trim();
    final navigator = Navigator.of(context);
    void ring() => navigator.push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _IncomingCall(name: name),
        ));
    if (_delay == 0) {
      ring();
      return;
    }
    _timer?.cancel();
    setState(() => _timer = Timer(Duration(seconds: _delay), () {
          setState(() => _timer = null);
          ring();
        }));
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _timer != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Fake Call')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Need a reason to leave? Your phone will ring as if someone is '
              'really calling. Keep this screen open until it rings.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Caller name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ring in',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _delays.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: _delay == entry.value,
                    onSelected: (_) => setState(() => _delay = entry.value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: waiting ? null : _schedule,
              icon: const Icon(Icons.phone_callback),
              label: Text(waiting ? 'Call scheduled...' : 'Schedule call'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingCall extends StatefulWidget {
  final String name;
  const _IncomingCall({required this.name});

  @override
  State<_IncomingCall> createState() => _IncomingCallState();
}

class _IncomingCallState extends State<_IncomingCall> {
  final _ringtone = LoopingAudio('audio/ringtone.wav');
  Timer? _clock;
  int _seconds = 0;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _ringtone.start();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ringtone.stop();
    super.dispose();
  }

  void _answer() {
    _ringtone.stop();
    setState(() => _answered = true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  String get _elapsed {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF101418),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF2C3238),
                    child: Text(
                      widget.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 44, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 34, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _answered ? _elapsed : 'Incoming call',
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: _answered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      _CallButton(
                        icon: Icons.call_end,
                        color: const Color(0xFFD93025),
                        label: _answered ? 'End call' : 'Decline',
                        onPressed: () => Navigator.pop(context),
                      ),
                      if (!_answered)
                        _CallButton(
                          icon: Icons.call,
                          color: const Color(0xFF1E8E3E),
                          label: 'Answer',
                          onPressed: _answer,
                        ),
                    ],
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

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;
  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
