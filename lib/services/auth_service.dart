import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'storage_service.dart';

/// A device-local account: the password is checked here and never leaves the
/// phone. It keeps casual users out of the app; it is not a server account, so
/// there's nothing to recover and a forgotten password just re-creates it.
class AuthService {
  AuthService({StorageService? storage}) : _storage = storage ?? StorageService();

  static const _iterations = 20000;
  final StorageService _storage;

  Future<bool> hasAccount() async => await _storage.getCredentials() != null;

  Future<void> signUp({
    required String name,
    required String phone,
    required String password,
  }) async {
    final salt = _randomBytes(16);
    await _storage.saveCredentials({
      'phone': phone,
      'salt': base64Encode(salt),
      'hash': base64Encode(_hash(password, salt, _iterations)),
      'iterations': _iterations,
    });
    final profile = await _storage.getProfile();
    await _storage.saveProfile(
      name: name,
      phone: phone,
      bloodGroup: profile['bloodGroup'] ?? '',
    );
    await _storage.setLoggedIn(true);
  }

  Future<bool> logIn({required String phone, required String password}) async {
    final credentials = await _storage.getCredentials();
    if (credentials == null || credentials['phone'] != phone) return false;
    final expected = base64Decode(credentials['hash'] as String);
    final actual = _hash(
      password,
      base64Decode(credentials['salt'] as String),
      credentials['iterations'] as int,
    );
    if (!_constantTimeEquals(expected, actual)) return false;
    await _storage.setLoggedIn(true);
    return true;
  }

  /// Removes the password only: contacts and settings stay on the phone.
  Future<void> resetAccount() => _storage.clearCredentials();

  /// PBKDF2-HMAC-SHA256 (one output block).
  static Uint8List _hash(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(block);
    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
