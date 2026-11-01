import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/emergency_contact.dart';
import '../models/incident.dart';

/// Wraps SharedPreferences to persist contacts, profile, settings and the
/// incident log locally on the device (no backend required).
class StorageService {
  static const _contactsKey = 'emergency_contacts';
  static const _nameKey = 'profile_name';
  static const _phoneKey = 'profile_phone';
  static const _bloodGroupKey = 'profile_blood_group';
  static const _loggedInKey = 'is_logged_in';
  static const _credentialsKey = 'account_credentials';
  static const _settingsKey = 'app_settings';
  static const _incidentsKey = 'incident_log';
  static const _activeIncidentKey = 'active_incident';
  static const _walkKey = 'safe_walk';
  static const _setupSeenKey = 'setup_seen';
  static const _nearbyKey = 'nearby_places';
  static const _maxIncidents = 50;

  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_contactsKey) ?? [];
    return raw
        .map((e) => EmergencyContact.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_contactsKey, raw);
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    required String bloodGroup,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_phoneKey, phone);
    await prefs.setString(_bloodGroupKey, bloodGroup);
  }

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_nameKey) ?? '',
      'phone': prefs.getString(_phoneKey) ?? '',
      'bloodGroup': prefs.getString(_bloodGroupKey) ?? '',
    };
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, value);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  Future<Map<String, dynamic>?> getCredentials() =>
      _readJson(_credentialsKey);

  Future<void> saveCredentials(Map<String, dynamic> credentials) =>
      _writeJson(_credentialsKey, credentials);

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credentialsKey);
  }

  Future<AppSettings> getSettings() async {
    final json = await _readJson(_settingsKey);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  Future<void> saveSettings(AppSettings settings) =>
      _writeJson(_settingsKey, settings.toJson());

  /// Newest first.
  Future<List<Incident>> getIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_incidentsKey) ?? [];
    return raw
        .map((e) => Incident.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addIncident(Incident incident) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_incidentsKey) ?? [];
    raw.insert(0, jsonEncode(incident.toJson()));
    await prefs.setStringList(_incidentsKey, raw.take(_maxIncidents).toList());
  }

  Future<void> clearIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_incidentsKey);
  }

  /// The running SOS, saved so it survives the app being killed.
  Future<Incident?> getActiveIncident() async {
    final json = await _readJson(_activeIncidentKey);
    return json == null ? null : Incident.fromJson(json);
  }

  Future<void> saveActiveIncident(Incident? incident) async {
    if (incident == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeIncidentKey);
    } else {
      await _writeJson(_activeIncidentKey, incident.toJson());
    }
  }

  Future<Map<String, dynamic>?> getSafeWalk() => _readJson(_walkKey);

  Future<void> saveSafeWalk(Map<String, dynamic>? walk) async {
    if (walk == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_walkKey);
    } else {
      await _writeJson(_walkKey, walk);
    }
  }

  Future<Map<String, dynamic>?> getNearby() => _readJson(_nearbyKey);

  Future<void> saveNearby(Map<String, dynamic> nearby) =>
      _writeJson(_nearbyKey, nearby);

  Future<bool> isSetupSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupSeenKey) ?? false;
  }

  Future<void> setSetupSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupSeenKey, true);
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _writeJson(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
