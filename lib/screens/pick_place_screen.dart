import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// Tap the map to choose where a Safe Walk ends.
class PickPlaceScreen extends StatefulWidget {
  final LatLng? initial;
  const PickPlaceScreen({super.key, this.initial});

  @override
  State<PickPlaceScreen> createState() => _PickPlaceScreenState();
}

class _PickPlaceScreenState extends State<PickPlaceScreen> {
  static const _india = LatLng(20.59, 78.96);
  final _controller = MapController();
  LatLng? _picked;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (_picked == null) _centreOnUser();
  }

  Future<void> _centreOnUser() async {
    final location = LocationService.instance;
    final fix = await location.currentFix(const Duration(seconds: 6)) ??
        await location.lastKnown();
    if (fix == null || !mounted || !_ready) return;
    _controller.move(LatLng(fix.latitude, fix.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose arrival point')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: picked ?? _india,
                  initialZoom: picked == null ? 5 : 15,
                  onMapReady: () => _ready = true,
                  onTap: (_, point) => setState(() => _picked = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.amritanshrai.safeher',
                  ),
                  if (picked != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: picked,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 44,
                          color: AppColors.sosRed,
                        ),
                      ),
                    ]),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: Color(0xB3FFFFFF),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed:
                    picked == null ? null : () => Navigator.pop(context, picked),
                child: Text(picked == null ? 'Tap the map' : 'Use this place'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
