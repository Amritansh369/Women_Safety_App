import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Wraps SharedPreferences to persist emergency contacts and profile info
/// locally on the device (no backend required for this MVP).
class StorageService {
  static const _contactsKey = 'emergency_contacts';
  static const _nameKey = 'profile_name';
  static const _phoneKey = 'profile_phone';
  static const _bloodGroupKey = 'profile_blood_group';
  static const _loggedInKey = 'is_logged_in';

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
}
