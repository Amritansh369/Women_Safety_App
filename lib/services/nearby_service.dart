import 'dart:async';
import 'dart:convert';
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

/// Finds police stations and hospitals from OpenStreetMap, which needs no API
/// key. Tries a second public server because these are run by volunteers.
class NearbyService {
  NearbyService({http.Client? client, StorageService? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? StorageService();

  static const _servers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const _timeout = Duration(seconds: 15);
  static const _radiusMetres = 5000;
  static const _userAgent = 'SafeHer personal safety app';

  final http.Client _client;
  final StorageService _storage;

  /// Saved results are only the fallback, so a stale list can't hide a working
  /// search. Null means there's nothing to show.
  Future<NearbyResult?> find(double latitude, double longitude) async {
    final query = '[out:json][timeout:12];('
        'nwr["amenity"="police"](around:$_radiusMetres,$latitude,$longitude);'
        'nwr["amenity"="hospital"](around:$_radiusMetres,$latitude,$longitude);'
        ');out center tags 80;';
    for (final server in _servers) {
      try {
        final response = await _client.post(
          Uri.parse(server),
          headers: {'User-Agent': _userAgent},
          body: {'data': query},
        ).timeout(_timeout);
        if (response.statusCode != 200) continue;
        final result = NearbyResult(
          places: parseOverpass(utf8.decode(response.bodyBytes)),
          latitude: latitude,
          longitude: longitude,
          savedAt: clock.now(),
        );
        await _storage.saveNearby(result.toJson());
        return result;
      } catch (e) {
        debugPrint('Nearby search failed on $server: $e');
      }
    }
    return saved();
  }

  Future<NearbyResult?> saved() async {
    final json = await _storage.getNearby();
    return json == null ? null : NearbyResult.fromCache(json);
  }

  /// Skips anything without a name or position: an unnamed pin isn't something
  /// a person in trouble can act on.
  @visibleForTesting
  static List<NearbyPlace> parseOverpass(String body) {
    final elements = (jsonDecode(body) as Map<String, dynamic>)['elements'];
    final places = <NearbyPlace>[];
    for (final element in (elements as List).cast<Map<String, dynamic>>()) {
      final tags = element['tags'] as Map<String, dynamic>? ?? const {};
      final centre = element['center'] as Map<String, dynamic>?;
      final latitude = (element['lat'] ?? centre?['lat']) as num?;
      final longitude = (element['lon'] ?? centre?['lon']) as num?;
      final name = (tags['name:en'] ?? tags['name']) as String?;
      if (latitude == null || longitude == null || name == null) continue;
      final phone = (tags['phone'] ?? tags['contact:phone']) as String? ?? '';
      places.add(NearbyPlace(
        name: name,
        kind: tags['amenity'] == 'police' ? PlaceKind.police : PlaceKind.hospital,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        // OpenStreetMap allows several numbers, separated by semicolons.
        phone: phone.split(';').first.trim(),
      ));
    }
    return places;
  }
}
