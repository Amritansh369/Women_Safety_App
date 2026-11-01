/// A single GPS reading, independent of the plugin that produced it.
class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final DateTime time;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.time,
  });

  /// True when the reading is recent enough to describe where the user is now.
  bool isFresh(DateTime now) =>
      now.difference(time) <= const Duration(minutes: 2);

  String get mapsLink =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}
