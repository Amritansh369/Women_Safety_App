import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

enum SmsResult { sent, failed, noPermission, unsupported }

abstract class SmsGateway {
  /// Sends without user interaction, and reports what the phone network said.
  Future<SmsResult> send(String phone, String message);

  /// Opens the messaging app pre-filled. The user still has to press send.
  Future<bool> openComposer(List<String> phones, String message);
}

/// Sends through Android's SmsManager (see MainActivity.kt). iOS does not let
/// apps send SMS on their own, so there [send] always falls back to the composer.
class DeviceSmsGateway implements SmsGateway {
  static const _channel = MethodChannel('safeher/device');
  static const _sendTimeout = Duration(seconds: 70);

  @override
  Future<SmsResult> send(String phone, String message) async {
    if (!Platform.isAndroid) return SmsResult.unsupported;
    if (!await Permission.sms.isGranted) return SmsResult.noPermission;
    try {
      final result = await _channel.invokeMethod<String>('sendSms', {
        'phone': phone,
        'message': message,
      }).timeout(_sendTimeout);
      return switch (result) {
        'sent' => SmsResult.sent,
        'no_permission' => SmsResult.noPermission,
        _ => SmsResult.failed,
      };
    } on PlatformException catch (e) {
      debugPrint('SMS to $phone failed: ${e.message}');
      return SmsResult.failed;
    } on TimeoutException {
      return SmsResult.failed;
    }
  }

  @override
  Future<bool> openComposer(List<String> phones, String message) async {
    // Encoded by hand: Uri(queryParameters:) turns spaces into '+', which many
    // messaging apps show literally.
    final body = Uri.encodeComponent(message);
    final uri = Platform.isIOS
        ? Uri.parse('sms:/open?addresses=${phones.join(',')}&body=$body')
        : Uri.parse('sms:${phones.join(',')}?body=$body');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open messaging app: $e');
      return false;
    }
  }

  /// Raises the alarm stream so the siren is heard even if it was turned down.
  static Future<void> maximizeAlarmVolume() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('maxAlarmVolume');
    } on PlatformException catch (e) {
      debugPrint('Could not raise alarm volume: ${e.message}');
    }
  }
}
