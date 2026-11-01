import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_info.dart';
import '../services/safe_walk_controller.dart';
import '../theme.dart';
import '../widgets/custom_time_dialog.dart';

/// Start a timed journey. If the user doesn't check in, the SOS sends itself.
class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen> {
  static const _durations = [10, 15, 20, 30, 45, 60];
  final _walk = SafeWalkController.instance;
  final _destinationCtrl = TextEditingController();
  int _minutes = 15;
  bool _notifyContacts = true;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Walk')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _walk,
          builder: (context, _) =>
              _walk.phase == WalkPhase.idle ? _setup() : _running(),
        ),
      ),
    );
  }

  Future<void> _pickCustomTime() async {
    final picked = await showCustomTimeDialog(
      context,
      title: 'I should arrive within',
      largeLabel: 'Hours',
      smallLabel: 'Minutes',
      largeUnit: const Duration(hours: 1),
      smallUnit: const Duration(minutes: 1),
      max: const Duration(hours: 8),
      initial: _durations.contains(_minutes)
          ? null
          : Duration(minutes: _minutes),
    );
    if (picked != null) setState(() => _minutes = picked.inMinutes);
  }

  Widget _setup() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Going somewhere alone? Set a time. If you don't check in by then, "
          '$appName asks if you are OK and, with no reply, sends your SOS '
          'with your location and where you were going.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _destinationCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Where are you going? (optional)',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'I should arrive within',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final minutes in _durations)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _minutes == minutes,
                onSelected: (_) => setState(() => _minutes = minutes),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.edit, size: 18),
              label: Text(
                _durations.contains(_minutes)
                    ? 'Custom'
                    : shortDuration(Duration(minutes: _minutes)),
              ),
              selected: !_durations.contains(_minutes),
              onSelected: (_) => _pickCustomTime(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _notifyContacts,
          onChanged: (value) => setState(() => _notifyContacts = value),
          title: const Text('Tell my contacts by SMS'),
          subtitle: const Text('They will know to expect you.'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _walk.start(
            duration: Duration(minutes: _minutes),
            destination: _destinationCtrl.text.trim(),
            notifyContacts: _notifyContacts,
          ),
          icon: const Icon(Icons.directions_walk),
          label: const Text('Start Safe Walk'),
        ),
      ],
    );
  }

  Widget _running() {
    final left = _walk.remaining;
    final minutes = left.inMinutes.toString().padLeft(2, '0');
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text(
            _walk.destination.isEmpty
                ? 'Check in by'
                : 'Heading to ${_walk.destination}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text('Due at ${DateFormat('HH:mm').format(_walk.deadline!)}'),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _walk.finish,
            icon: const Icon(Icons.check),
            label: const Text("I've arrived safely"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _walk.extend(const Duration(minutes: 10)),
            icon: const Icon(Icons.more_time),
            label: const Text('Add 10 minutes'),
          ),
        ],
      ),
    );
  }
}
