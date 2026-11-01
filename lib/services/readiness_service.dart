import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'storage_service.dart';

/// The checks that decide whether an SOS would really work right now.
class Readiness {
  final int contacts;
  final bool locationGranted;
  final bool locationServiceOn;
  final bool smsGranted;
  final bool notificationsGranted;

  const Readiness({
    required this.contacts,
    required this.locationGranted,
    required this.locationServiceOn,
    required this.smsGranted,
    required this.notificationsGranted,
  });

  /// Android-only: iOS has no automatic SMS to enable.
  bool get canAutoSend => Platform.isAndroid;

  int get missing => [
        contacts > 0,
        locationGranted,
        locationServiceOn,
        !canAutoSend || smsGranted,
        notificationsGranted,
      ].where((ok) => !ok).length;

  bool get allGood => missing == 0;
}

class ReadinessService {
  final _storage = StorageService();

  Future<Readiness> check() async {
    final contacts = await _storage.getContacts();
    return Readiness(
      contacts: contacts.length,
      locationGranted: await Permission.locationWhenInUse.isGranted,
      locationServiceOn: await Geolocator.isLocationServiceEnabled(),
      smsGranted: Platform.isAndroid && await Permission.sms.isGranted,
      notificationsGranted: await Permission.notification.isGranted,
    );
  }

  /// Asks for [permission], or sends the user to system settings if Android
  /// will no longer show the prompt.
  Future<void> request(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) await openAppSettings();
  }
}
