import 'package:geolocator/geolocator.dart';

/// Handles permission checks and fetching the device's current GPS location.
class LocationService {
  /// Returns the current position, requesting permission if needed.
  /// Throws a descriptive [Exception] if location can't be obtained.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
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
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// A live stream of position updates, used for the tracking screen.
  Stream<Position> watchLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  String googleMapsLink(double lat, double lng) =>
      'https://maps.google.com/?q=$lat,$lng';
}
