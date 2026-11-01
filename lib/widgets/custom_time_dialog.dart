import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Short label for a chosen time, such as "1 h 25 min" or "2 min 30 sec".
String shortDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  return [
    if (hours > 0) '$hours h',
    if (minutes > 0) '$minutes min',
    if (seconds > 0) '$seconds sec',
  ].join(' ');
}

/// Asks for a time in two units, such as hours and minutes. Returns null if
/// cancelled.
Future<Duration?> showCustomTimeDialog(
  BuildContext context, {
  required String title,
  required String largeLabel,
  required String smallLabel,
  required Duration largeUnit,
  required Duration smallUnit,
  required Duration max,
  Duration? initial,
}) {
  return showDialog<Duration>(
    context: context,
    builder: (_) => _CustomTimeDialog(
      title: title,
      largeLabel: largeLabel,
      smallLabel: smallLabel,
      largeUnit: largeUnit,
      smallUnit: smallUnit,
      max: max,
      initial: initial ?? Duration.zero,
    ),
  );
}

class _CustomTimeDialog extends StatefulWidget {
  final String title;
  final String largeLabel;
  final String smallLabel;
  final Duration largeUnit;
  final Duration smallUnit;
  final Duration max;
  final Duration initial;

  const _CustomTimeDialog({
    required this.title,
    required this.largeLabel,
    required this.smallLabel,
    required this.largeUnit,
    required this.smallUnit,
    required this.max,
    required this.initial,
  });

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late final _largeCtrl = TextEditingController(text: _initialText(true));
  late final _smallCtrl = TextEditingController(text: _initialText(false));
  String? _error;

  String _initialText(bool large) {
    final units = widget.initial.inSeconds ~/ widget.largeUnit.inSeconds;
    final rest = (widget.initial - widget.largeUnit * units).inSeconds ~/
        widget.smallUnit.inSeconds;
    final value = large ? units : rest;
    return value == 0 ? '' : '$value';
  }

  @override
  void dispose() {
    _largeCtrl.dispose();
    _smallCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final large = int.tryParse(_largeCtrl.text) ?? 0;
    final small = int.tryParse(_smallCtrl.text) ?? 0;
    final total = widget.largeUnit * large + widget.smallUnit * small;
    if (total == Duration.zero) {
      setState(() => _error = 'Enter a time');
    } else if (total > widget.max) {
      setState(() => _error = 'Choose ${shortDuration(widget.max)} or less');
    } else {
      Navigator.pop(context, total);
    }
  }

  Widget _field(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _field(_largeCtrl, widget.largeLabel),
              const SizedBox(width: 12),
              _field(_smallCtrl, widget.smallLabel),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Set time')),
      ],
    );
  }
}
