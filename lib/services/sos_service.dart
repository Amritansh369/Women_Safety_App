import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';

/// Builds and dispatches the emergency SOS message (with live location link)
/// to every trusted contact via the device's SMS app.
class SosService {
  final LocationService _locationService = LocationService();

  Future<String> buildSosMessage() async {
    final position = await _locationService.getCurrentLocation();
    final link = _locationService.googleMapsLink(
      position.latitude,
      position.longitude,
    );
    return 'EMERGENCY! I need help right now. This is my live location: $link '
        '— Sent automatically from Women Safety App.';
  }

  /// Opens the SMS app pre-filled with the SOS message, addressed to all
  /// [contacts] at once (comma-separated recipients).
  Future<void> sendSos(List<EmergencyContact> contacts) async {
    if (contacts.isEmpty) {
      throw Exception('Add at least one emergency contact first.');
    }
    final message = await buildSosMessage();
    final numbers = contacts.map((c) => c.phone).join(',');

    final uri = Uri(
      scheme: 'sms',
      path: numbers,
      queryParameters: {'body': message},
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Could not open messaging app.');
    }
  }

  Future<void> callContact(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched) {
      throw Exception('Could not start call.');
    }
  }
}
