import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/incident.dart';
import 'emergency_controller.dart';
import 'location_service.dart';
import 'storage_service.dart';

/// Recognises a deliberate, hard shake. Needs several strong peaks close
/// together so that walking, running or a phone in a bag doesn't set it off.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 27, // m/s^2, about 2.75 g
    this.requiredPeaks = 4,
    this.window = const Duration(milliseconds: 1500),
    this.minPeakGap = const Duration(milliseconds: 120),
  });

  final double threshold;
  final int requiredPeaks;
  final Duration window;
  final Duration minPeakGap;
  final _peaks = <DateTime>[];

  /// Feeds one accelerometer sample; returns true when a shake completes.
  bool addSample(double x, double y, double z, DateTime time) {
    if (sqrt(x * x + y * y + z * z) < threshold) return false;
    if (_peaks.isNotEmpty && time.difference(_peaks.last) < minPeakGap) {
      return false;
    }
    _peaks.add(time);
    _peaks.removeWhere((t) => time.difference(t) > window);
    if (_peaks.length < requiredPeaks) return false;
    _peaks.clear();
    return true;
  }
}

/// Connects the accelerometer to the SOS while the user has shake enabled.
class ShakeService {
  ShakeService._();
  static final instance = ShakeService._();

  static const _holdReason = 'guardian';

  final _storage = StorageService();
  final _detector = ShakeDetector();
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// Applies the saved settings. Call on login and when settings change.
  Future<void> sync() async {
    final settings = await _storage.getSettings();
    if (settings.shakeEnabled) {
      _subscription ??= accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onSample, onError: (Object e) {
        debugPrint('Accelerometer unavailable: $e');
      });
    } else {
      await _subscription?.cancel();
      _subscription = null;
    }

    // Low accuracy: this hold only exists to keep the app running, so that the
    // shake still works with the screen off, at a modest battery cost.
    if (settings.shakeEnabled && settings.guardianMode) {
      LocationService.instance
          .hold(_holdReason, background: true, precise: false);
    } else {
      LocationService.instance.release(_holdReason);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    LocationService.instance.release(_holdReason);
  }

  void _onSample(AccelerometerEvent event) {
    if (_detector.addSample(event.x, event.y, event.z, event.timestamp)) {
      unawaited(
        EmergencyController.instance.startCountdown(IncidentTrigger.shake),
      );
    }
  }
}
