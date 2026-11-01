import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_info.dart';
import '../models/location_fix.dart';

/// Builds the text of every message the app sends. Stays in plain ASCII where
/// possible: one non-GSM character (even a long dash) cuts an SMS segment from
/// 160 characters to 70, which costs the user more and splits the map link.
class SosMessages {
  static String alert({
    required String name,
    required LocationFix? fix,
    required DateTime now,
    String bloodGroup = '',
    String customMessage = '',
    String destination = '',
  }) {
    final who = name.trim().isEmpty ? 'Your contact' : name.trim();
    final opening = customMessage.trim().isEmpty
        ? 'SOS! $who needs help now.'
        : 'SOS from $who: ${customMessage.trim()}';
    final blood = bloodGroup.trim().isEmpty
        ? ''
        : ' Blood group ${bloodGroup.trim()}.';
    final heading = destination.trim().isEmpty
        ? ''
        : ' Was heading to ${destination.trim()}.';
    return '$opening ${_where(fix, now)}$heading$blood Please call them. '
        'Sent by $appName.';
  }

  static String update({required LocationFix? fix, required DateTime now}) =>
      '$appName update: SOS still active. ${_where(fix, now)}';

  static String allClear(String name) {
    final who = name.trim().isEmpty ? 'Your contact' : name.trim();
    return '$appName: $who has marked themselves safe. The SOS has ended.';
  }

  static String test(String name) {
    final who = name.trim().isEmpty ? 'Your contact' : name.trim();
    return 'This is a TEST from $appName. $who added you as an emergency '
        'contact. No action is needed.';
  }

  static String walkStarted(String name, String destination, DateTime eta) {
    final who = name.trim().isEmpty ? 'Your contact' : name.trim();
    final place = destination.trim().isEmpty ? '' : ' to ${destination.trim()}';
    return '$appName: $who started a Safe Walk$place and should arrive by '
        '${_time(eta)}. You will get an SOS if they do not check in.';
  }

  static String _where(LocationFix? fix, DateTime now) {
    if (fix == null) return 'Location unavailable right now.';
    final prefix = fix.isFresh(now) ? 'Location' : 'Last known location';
    return '$prefix: ${fix.mapsLink} (within ${fix.accuracy.round()} m, '
        '${_time(fix.time)}).';
  }

  static String _time(DateTime time) =>
      DateFormat('HH:mm').format(time.toLocal());
}

/// Places a phone call through the dialer.
Future<bool> callNumber(String phone) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    return false;
  }
}
