import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_fix.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/sos_service.dart';
import '../theme.dart';
import 'helplines_screen.dart';

/// Police stations and hospitals around the user. The last search is kept on
/// the phone, so the list still works with no signal.
class NearbyScreen extends StatefulWidget {
  final NearbyService? service;
  final Future<LocationFix?> Function()? locate;
  const NearbyScreen({super.key, this.service, this.locate});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const _maxPlaces = 30;
  late final _service = widget.service ?? NearbyService();
  NearbyResult? _result;
  LocationFix? _fix;
  bool _loading = true;
  String _status = 'Finding your location...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<LocationFix?> _locate() async {
    final location = LocationService.instance;
    return await location.currentFix(const Duration(seconds: 8)) ??
        await location.lastKnown();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  /// Always ends by leaving the spinner, whatever goes wrong: an endless
  /// spinner tells someone who needs help nothing.
  Future<void> _load() async {
    LocationFix? fix;
    NearbyResult? result;
    try {
      fix = await (widget.locate ?? _locate)();
      _setStatus('Searching for help nearby...');
      result = fix == null
          ? await _service.saved()
          : await _service.find(fix.latitude, fix.longitude);
    } catch (e) {
      debugPrint('Nearby Help failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _result = result;
      _loading = false;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _status = 'Finding your location...';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Help'),
        actions: [
          IconButton(
            tooltip: 'Search again',
            onPressed: _loading ? null : _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_status),
                  ],
                ),
              )
            : result == null
                ? _nothingToShow()
                : _list(result),
      ),
    );
  }

  Widget _nothingToShow() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: AppColors.warning),
            const SizedBox(height: 12),
            const Text(
              "Couldn't search. This needs your location and an internet "
              'connection the first time. Helplines work without either.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _retry, child: const Text('Try again')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HelplinesScreen()),
              ),
              child: const Text('Open Helplines'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(NearbyResult result) {
    final fix = _fix;
    final origin = fix == null
        ? LatLng(result.latitude, result.longitude)
        : LatLng(fix.latitude, fix.longitude);
    double metres(NearbyPlace place) => const Distance().as(
          LengthUnit.Meter,
          origin,
          LatLng(place.latitude, place.longitude),
        );
    final places = [...result.places]
      ..sort((a, b) => metres(a).compareTo(metres(b)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (result.fromCache)
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_off, color: AppColors.warning),
              title: const Text(
                'Showing your last saved search',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'From ${DateFormat('d MMM, HH:mm').format(result.savedAt)}. '
                'It may be for a different area.',
              ),
            ),
          ),
        if (places.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Nothing listed within 5 km. Map data can be incomplete, so use '
              'Helplines if you need help now.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final place in places.take(_maxPlaces))
          _PlaceCard(place: place, metres: metres(place)),
        const SizedBox(height: 12),
        const Text(
          'Your location is sent to a public OpenStreetMap search service for '
          'this. Entries can be incomplete or out of date. © OpenStreetMap '
          'contributors.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final NearbyPlace place;
  final double metres;
  const _PlaceCard({required this.place, required this.metres});

  String get _distance => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final police = place.kind == PlaceKind.police;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          police ? Icons.local_police : Icons.local_hospital,
          color: police ? AppColors.primary : AppColors.sosRed,
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${police ? 'Police' : 'Hospital'}, $_distance away'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place.phone.isNotEmpty)
              IconButton(
                tooltip: 'Call',
                icon: const Icon(Icons.call, color: AppColors.success),
                onPressed: () => callNumber(place.phone),
              ),
            IconButton(
              tooltip: 'Directions',
              icon: const Icon(Icons.directions),
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination='
                  '${place.latitude},${place.longitude}',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
