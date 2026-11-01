import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_fix.dart';
import '../theme.dart';

/// OpenStreetMap view that follows [fix]. Needs no API key.
class LiveMap extends StatefulWidget {
  final LocationFix fix;
  const LiveMap({super.key, required this.fix});

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final _controller = MapController();
  bool _ready = false;

  LatLng get _point => LatLng(widget.fix.latitude, widget.fix.longitude);

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready) _controller.move(_point, _controller.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _point,
        initialZoom: 16,
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.amritanshrai.safeher',
        ),
        CircleLayer(circles: [
          CircleMarker(
            point: _point,
            radius: widget.fix.accuracy,
            useRadiusInMeter: true,
            color: AppColors.accent.withValues(alpha: 0.15),
            borderColor: AppColors.accent.withValues(alpha: 0.5),
            borderStrokeWidth: 1,
          ),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: _point,
            width: 24,
            height: 24,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ]),
        const Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: Color(0xB3FFFFFF),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
