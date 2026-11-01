import 'dart:async';
import 'package:clock/clock.dart';
import 'package:women_safety_app/models/location_fix.dart';
import 'package:women_safety_app/services/location_service.dart';
import 'package:women_safety_app/services/siren_service.dart';
import 'package:women_safety_app/services/sms_service.dart';

class SentSms {
  final String phone;
  final String message;
  SentSms(this.phone, this.message);
}

class FakeSms implements SmsGateway {
  final sent = <SentSms>[];
  final attempts = <String, int>{};
  final composerCalls = <List<String>>[];
  final failuresLeft = <String, int>{};
  final delays = <String, Duration>{};
  SmsResult? alwaysReturn;
  bool composerOpens = true;

  @override
  Future<SmsResult> send(String phone, String message) async {
    attempts[phone] = (attempts[phone] ?? 0) + 1;
    final delay = delays[phone];
    if (delay != null) await Future<void>.delayed(delay);
    if (alwaysReturn != null) return alwaysReturn!;
    final failures = failuresLeft[phone] ?? 0;
    if (failures > 0) {
      failuresLeft[phone] = failures - 1;
      return SmsResult.failed;
    }
    sent.add(SentSms(phone, message));
    return SmsResult.sent;
  }

  @override
  Future<bool> openComposer(List<String> phones, String message) async {
    composerCalls.add(phones);
    return composerOpens;
  }
}

class FakeLocation implements LocationSource {
  final stream = StreamController<LocationFix>.broadcast();
  final holds = <String>{};
  LocationFix? current;
  LocationFix? last;
  Duration? currentDelay;
  bool throws = false;

  @override
  Future<LocationFix?> lastKnown() async => last;

  @override
  Future<LocationFix?> currentFix(Duration timeout) async {
    if (throws) throw Exception('GPS exploded');
    if (currentDelay != null) await Future<void>.delayed(currentDelay!);
    return current;
  }

  @override
  Stream<LocationFix> get fixes => stream.stream;

  @override
  void hold(String reason, {bool background = false, bool precise = true}) {
    holds.add(reason);
  }

  @override
  void release(String reason) => holds.remove(reason);
}

class FakeSiren implements Siren {
  @override
  bool isPlaying = false;

  @override
  Future<void> start() async => isPlaying = true;

  @override
  Future<void> stop() async => isPlaying = false;
}

LocationFix fixAt(DateTime time, {double latitude = 12.9716}) => LocationFix(
      latitude: latitude,
      longitude: 77.5946,
      accuracy: 12,
      time: time,
    );

LocationFix freshFix() => fixAt(clock.now());
