import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_fix.dart';

/// The location features the emergency flow depends on. Every method reports
/// "no location" rather than throwing, because a missing GPS fix must never
/// stop an alert from going out.
abstract class LocationSource {
  Future<LocationFix?> lastKnown();
  Future<LocationFix?> currentFix(Duration timeout);
  Stream<LocationFix> get fixes;

  /// Keeps location updates flowing until [release] is called with the same
  /// [reason]. [background] keeps the app running via a foreground service.
  void hold(String reason, {bool background = false, bool precise = true});
  void release(String reason);
}

class _Hold {
  final bool background;
  final bool precise;
  const _Hold(this.background, this.precise);
}

/// Handles permission checks and the device's GPS. Geolocator shares one
/// position stream per app, so all callers go through a single subscription
/// that is restarted whenever the combined needs of the holders change.
class LocationService implements LocationSource {
  LocationService._();
  static final instance = LocationService._();

  static const _device = MethodChannel('safeher/device');
  static const _noFixTimeout = Duration(seconds: 20);
  static const _protectionRetry = Duration(seconds: 5);

  final _fixes = StreamController<LocationFix>.broadcast();
  final _holds = <String, _Hold>{};
  StreamSubscription<Position>? _subscription;
  Timer? _restart;
  Timer? _protectionTimer;
  bool _protected = false;
  bool _precise = false;
  bool _gotFix = false;

  /// Returns the current position, requesting permission if needed.
  /// Throws a descriptive [Exception] if location can't be obtained.
  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Enable it from app settings.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  @override
  Future<LocationFix?> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : _toFix(position);
    } catch (e) {
      debugPrint('Last known location unavailable: $e');
      return null;
    }
  }

  @override
  Future<LocationFix?> currentFix(Duration timeout) async {
    try {
      return _toFix(await getCurrentLocation().timeout(timeout));
    } catch (e) {
      debugPrint('Current location unavailable: $e');
      return null;
    }
  }

  @override
  Stream<LocationFix> get fixes => _fixes.stream;

  @override
  void hold(String reason, {bool background = false, bool precise = true}) {
    _holds[reason] = _Hold(background, precise);
    _applyHolds();
  }

  @override
  void release(String reason) {
    _holds.remove(reason);
    _applyHolds();
  }

  void _applyHolds() {
    final background = _holds.values.any((h) => h.background);
    unawaited(_setProtection(background));

    _restart?.cancel();
    if (_holds.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
      return;
    }
    final precise = _holds.values.any((h) => h.precise);
    if (_subscription != null && precise == _precise) return;
    _precise = precise;
    _subscribe(background);
  }

  /// Starts or stops the native foreground service that keeps the app alive.
  /// Android can refuse the start, so it's retried while it's still needed.
  Future<void> _setProtection(bool wanted) async {
    _protectionTimer?.cancel();
    if (!Platform.isAndroid || wanted == _protected) return;
    try {
      final done = await _device.invokeMethod<bool>(
        wanted ? 'startProtection' : 'stopProtection',
      );
      if (done == true) _protected = wanted;
    } on PlatformException catch (e) {
      debugPrint('Could not change protection: ${e.message}');
    }
    if (wanted != _protected) {
      _protectionTimer = Timer(_protectionRetry, _applyHolds);
    }
  }

  Future<void> _subscribe(bool background) async {
    await _subscription?.cancel();
    _gotFix = false;
    _subscription = Geolocator.getPositionStream(
      locationSettings: _settings(background, _precise),
    ).listen(
      (position) {
        _gotFix = true;
        _fixes.add(_toFix(position));
      },
      // Usually a denied permission or GPS switched off. Keep trying for as
      // long as someone needs location: the user may fix it mid-emergency.
      onError: (Object e) {
        debugPrint('Location stream error: $e');
        _subscription?.cancel();
        _subscription = null;
        _restart?.cancel();
        _restart = Timer(const Duration(seconds: 15), _applyHolds);
      },
    );
    // Geolocator silently returns a dead stream if it's started before its
    // Android service has bound, as happens when an SOS resumes at launch.
    _restart?.cancel();
    _restart = Timer(_noFixTimeout, () {
      if (!_gotFix && _holds.isNotEmpty) _subscribe(background);
    });
  }

  LocationSettings _settings(bool background, bool precise) {
    final accuracy = precise ? LocationAccuracy.high : LocationAccuracy.low;
    final distanceFilter = precise ? 5 : 100;
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  LocationFix _toFix(Position position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        time: position.timestamp,
      );
}
