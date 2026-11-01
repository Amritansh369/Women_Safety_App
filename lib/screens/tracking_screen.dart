import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_fix.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/live_map.dart';

/// Shows the user's position on a live map and lets them share it. A shared
/// link is a snapshot of where they are now: following a moving position
/// remotely would need a server, so only the SOS sends repeat updates.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  static const _holdReason = 'tracking_screen';
  final _location = LocationService.instance;
  StreamSubscription<LocationFix>? _subscription;
  LocationFix? _fix;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _location.release(_holdReason);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final position = await _location.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _fix = LocationFix(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          time: position.timestamp,
        );
      });
      _subscription ??= _location.fixes.listen((fix) {
        setState(() => _fix = fix);
      });
      _location.hold(_holdReason);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _share(LocationFix fix) async {
    await SharePlus.instance.share(
      ShareParams(text: 'My current location: ${fix.mapsLink}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fix = _fix;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Location')),
      body: SafeArea(
        child: _error != null
            ? _Problem(message: _error!, onRetry: _start)
            : fix == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(child: LiveMap(fix: fix)),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _CoordRow(
                              label: 'Coordinates',
                              value: '${fix.latitude.toStringAsFixed(5)}, '
                                  '${fix.longitude.toStringAsFixed(5)}',
                            ),
                            const SizedBox(height: 6),
                            _CoordRow(
                              label: 'Accuracy',
                              value: '${fix.accuracy.toStringAsFixed(0)} m',
                            ),
                            const SizedBox(height: 6),
                            _CoordRow(
                              label: 'Updated',
                              value: DateFormat('HH:mm:ss')
                                  .format(fix.time.toLocal()),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _share(fix),
                              icon: const Icon(Icons.share),
                              label: const Text('Share my location'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => launchUrl(
                                Uri.parse(fix.mapsLink),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('Open in Google Maps'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Problem({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 56, color: AppColors.sosRed),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  const _CoordRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
