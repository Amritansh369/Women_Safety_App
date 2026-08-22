import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// Shows the user's live-updating GPS coordinates and lets them open
/// or share their current location as a Google Maps link.
///
/// Note: for a production map view (with a visual map, not just
/// coordinates), embed `google_maps_flutter` and feed it this same
/// position stream as markers.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _locationService = LocationService();
  Position? _position;
  String? _error;
  bool _tracking = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startTracking() async {
    setState(() {
      _tracking = true;
      _error = null;
    });
    try {
      final pos = await _locationService.getCurrentLocation();
      setState(() => _position = pos);
      _locationService.watchLocation().listen(
        (pos) => setState(() => _position = pos),
        onError: (e) => setState(() => _error = e.toString()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _tracking = false;
      });
    }
  }

  Future<void> _openInMaps() async {
    if (_position == null) return;
    final link = _locationService.googleMapsLink(
        _position!.latitude, _position!.longitude);
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!_tracking)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined,
                            size: 72, color: AppColors.accent),
                        const SizedBox(height: 16),
                        const Text(
                          'Share your live location so trusted\ncontacts can follow your journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _startTracking,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Live Tracking'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: AppColors.sosRed)),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle,
                                color: AppColors.success, size: 10),
                            SizedBox(width: 8),
                            Text('Tracking active',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _position == null
                              ? const CircularProgressIndicator()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _CoordRow(
                                        label: 'Latitude',
                                        value: _position!.latitude
                                            .toStringAsFixed(6)),
                                    const SizedBox(height: 10),
                                    _CoordRow(
                                        label: 'Longitude',
                                        value: _position!.longitude
                                            .toStringAsFixed(6)),
                                    const SizedBox(height: 10),
                                    _CoordRow(
                                        label: 'Accuracy',
                                        value:
                                            '${_position!.accuracy.toStringAsFixed(0)} m'),
                                  ],
                                ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _position == null ? null : _openInMaps,
                        icon: const Icon(Icons.map),
                        label: const Text('Open in Google Maps'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _tracking = false),
                        icon: const Icon(Icons.stop, color: AppColors.sosRed),
                        label: const Text('Stop Tracking',
                            style: TextStyle(color: AppColors.sosRed)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
