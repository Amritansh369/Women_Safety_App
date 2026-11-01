import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

enum PlaceKind { police, hospital }

class NearbyPlace {
  final String name;
  final PlaceKind kind;
  final double latitude;
  final double longitude;
  final String phone;

  const NearbyPlace({
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
      };

  factory NearbyPlace.fromJson(Map<String, dynamic> json) => NearbyPlace(
        name: json['name'] as String,
        kind: PlaceKind.values.byName(json['kind'] as String),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        phone: json['phone'] as String? ?? '',
      );
}

/// What the last search found, kept so it still works with no signal.
class NearbyResult {
  final List<NearbyPlace> places;
  final double latitude;
  final double longitude;
  final DateTime savedAt;
  final bool fromCache;

  const NearbyResult({
    required this.places,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
    this.fromCache = false,
  });

  Map<String, dynamic> toJson() => {
        'places': places.map((p) => p.toJson()).toList(),
        'latitude': latitude,
        'longitude': longitude,
        'savedAt': savedAt.toIso8601String(),
      };

  factory NearbyResult.fromCache(Map<String, dynamic> json) => NearbyResult(
        places: (json['places'] as List)
            .map((p) => NearbyPlace.fromJson(p as Map<String, dynamic>))
            .toList(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        savedAt: DateTime.parse(json['savedAt'] as String),
        fromCache: true,
      );
}

/// Finds police stations and hospitals from OpenStreetMap data, which needs no
/// API key. These public servers are run for free and do go down, so a second
/// service is tried, and timeouts are short because someone is waiting.
class NearbyService {
  NearbyService({
    http.Client? client,
    StorageService? storage,
    this.politeDelay = const Duration(milliseconds: 1100),
  })  : _client = client ?? http.Client(),
        _storage = storage ?? StorageService();

  static const _timeout = Duration(seconds: 8);
  static const _searchKm = 5.0;
  static const _kmPerDegree = 111.0;
  static const _headers = {
    'User-Agent':
        'SafeHer personal safety app (github.com/Amritansh369/Women_Safety_App)',
  };

  /// Nominatim's usage policy allows one request a second.
  final Duration politeDelay;
  final http.Client _client;
  final StorageService _storage;

  /// Saved results are only the fallback, so a stale list can't hide a working
  /// search. Null means there's nothing to show.
  Future<NearbyResult?> find(double latitude, double longitude) async {
    final latSpan = _searchKm / _kmPerDegree;
    final lonSpan = latSpan / cos(latitude * pi / 180);
    final box = _Box(
      west: longitude - lonSpan,
      south: latitude - latSpan,
      east: longitude + lonSpan,
      north: latitude + latSpan,
    );
    for (final search in [_nominatim, _photon]) {
      try {
        final result = NearbyResult(
          places: await search(box),
          latitude: latitude,
          longitude: longitude,
          savedAt: clock.now(),
        );
        if (result.places.isNotEmpty) await _storage.saveNearby(result.toJson());
        return result;
      } catch (e) {
        debugPrint('Nearby search failed: $e');
      }
    }
    return saved();
  }

  /// A damaged copy counts as no copy, so it can't break the screen.
  Future<NearbyResult?> saved() async {
    try {
      final json = await _storage.getNearby();
      return json == null ? null : NearbyResult.fromCache(json);
    } catch (e) {
      debugPrint('Ignoring saved nearby places: $e');
      return null;
    }
  }

  Future<List<NearbyPlace>> _nominatim(_Box box) async {
    final places = <NearbyPlace>[];
    for (final kind in PlaceKind.values) {
      if (places.isNotEmpty) await Future<void>.delayed(politeDelay);
      final body = await _get(Uri.https('nominatim.openstreetmap.org', '/search', {
        'amenity': kind.name,
        'viewbox': '${box.west},${box.north},${box.east},${box.south}',
        'bounded': '1',
        'format': 'jsonv2',
        'extratags': '1',
        'limit': '30',
        'accept-language': 'en',
      }));
      places.addAll(parseNominatim(body, kind));
    }
    return places;
  }

  Future<List<NearbyPlace>> _photon(_Box box) async {
    final places = <NearbyPlace>[];
    for (final kind in PlaceKind.values) {
      final body = await _get(Uri.https('photon.komoot.io', '/api/', {
        'q': kind.name,
        'osm_tag': 'amenity:${kind.name}',
        'bbox': '${box.west},${box.south},${box.east},${box.north}',
        'limit': '30',
      }));
      places.addAll(parsePhoton(body, kind));
    }
    return places;
  }

  Future<String> _get(Uri uri) async {
    final response =
        await _client.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return utf8.decode(response.bodyBytes);
  }

  /// Skips anything without a name: an unnamed pin isn't something a person in
  /// trouble can act on.
  @visibleForTesting
  static List<NearbyPlace> parseNominatim(String body, PlaceKind kind) {
    final places = <NearbyPlace>[];
    for (final item in (jsonDecode(body) as List).cast<Map<String, dynamic>>()) {
      final name = item['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final tags = item['extratags'] as Map<String, dynamic>? ?? const {};
      final phone = (tags['phone'] ?? tags['contact:phone']) as String? ?? '';
      places.add(NearbyPlace(
        name: name,
        kind: kind,
        latitude: double.parse(item['lat'] as String),
        longitude: double.parse(item['lon'] as String),
        // OpenStreetMap allows several numbers, separated by semicolons.
        phone: phone.split(';').first.trim(),
      ));
    }
    return places;
  }

  @visibleForTesting
  static List<NearbyPlace> parsePhoton(String body, PlaceKind kind) {
    final features = (jsonDecode(body) as Map<String, dynamic>)['features'];
    final places = <NearbyPlace>[];
    for (final feature in (features as List).cast<Map<String, dynamic>>()) {
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final name = properties['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final point = (geometry['coordinates'] as List).cast<num>();
      places.add(NearbyPlace(
        name: name,
        kind: kind,
        latitude: point[1].toDouble(),
        longitude: point[0].toDouble(),
      ));
    }
    return places;
  }
}

class _Box {
  final double west;
  final double south;
  final double east;
  final double north;
  const _Box({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });
}
