import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/incident.dart';
import 'emergency_controller.dart';
import 'storage_service.dart';

/// The Android side talking to Dart: delivery reports, and the Quick Settings
/// tile, widget and notification button, which all ask for an SOS here.
class DeviceEvents {
  static const _channel = MethodChannel('safeher/device');
  static final _deliveries = StreamController<String>.broadcast();

  static Stream<String> get deliveries => _deliveries.stream;

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(_onCall);
    EmergencyController.instance.addListener(_onEmergencyChanged);
    await _consumeSosRequest();
    final settings = await StorageService().getSettings();
    await setQuickSos(settings.quickSos);
  }

  static Future<dynamic> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'smsDelivered':
        _deliveries.add(call.arguments as String);
      case 'sosRequested':
        await _consumeSosRequest();
    }
  }

  // Both a cold start and a running app land here, and the request is cleared
  // natively when it's read, so one press can't start two countdowns.
  static Future<void> _consumeSosRequest() async {
    final requested = await _invoke<bool>('consumeSosRequest');
    if (requested == true) {
      await EmergencyController.instance
          .startCountdown(IncidentTrigger.shortcut);
    }
  }

  /// A shortcut shows the SOS over the lock screen. Once it's over, the rest
  /// of the app must go back behind the lock.
  static void _onEmergencyChanged() {
    if (EmergencyController.instance.phase == EmergencyPhase.idle) {
      unawaited(_invoke<void>('leaveLockScreen'));
    }
  }

  static Future<void> setQuickSos(bool enabled) =>
      _invoke<void>('setQuickSos', {'enabled': enabled});

  static Future<void> postNotice(String title, String text) =>
      _invoke<void>('postNotice', {'title': title, 'text': text});

  /// Null when unknown or charging, when a low battery isn't a concern.
  static Future<int?> batteryLevel() => _invoke<int>('batteryLevel');

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('$method failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('$method unavailable: ${e.message}');
    }
    return null;
  }
}
