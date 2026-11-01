import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../models/incident.dart';
import 'emergency_controller.dart';
import 'location_service.dart';
import 'siren_service.dart';
import 'sms_service.dart';
import 'sos_service.dart';
import 'storage_service.dart';

enum WalkPhase { idle, walking, checkIn }

/// A dead-man's switch for a journey: if the user doesn't confirm they arrived
/// by the deadline, and then doesn't answer a loud check-in, the SOS fires by
/// itself. Timing uses the wall clock, so it stays correct if timers are delayed
/// while the phone sleeps or the app restarts.
class SafeWalkController extends ChangeNotifier {
  SafeWalkController({
    required EmergencyController emergency,
    required LocationSource location,
    required StorageService storage,
    required SmsGateway sms,
    required Siren alarm,
    this.gracePeriod = const Duration(seconds: 60),
  })  : _emergency = emergency,
        _location = location,
        _storage = storage,
        _sms = sms,
        _alarm = alarm;

  static final instance = SafeWalkController(
    emergency: EmergencyController.instance,
    location: LocationService.instance,
    storage: StorageService(),
    sms: DeviceSmsGateway(),
    alarm: LoopingAudio('audio/siren.wav', maximizeVolume: true),
  );

  static const _holdReason = 'safe_walk';

  final EmergencyController _emergency;
  final LocationSource _location;
  final StorageService _storage;
  final SmsGateway _sms;
  final Siren _alarm;
  final Duration gracePeriod;

  WalkPhase _phase = WalkPhase.idle;
  DateTime? _deadline;
  String _destination = '';
  Timer? _ticker;

  WalkPhase get phase => _phase;
  DateTime? get deadline => _deadline;
  String get destination => _destination;

  Duration get remaining {
    final deadline = _deadline;
    if (deadline == null) return Duration.zero;
    final end = _phase == WalkPhase.checkIn ? deadline.add(gracePeriod) : deadline;
    final left = end.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> start({
    required Duration duration,
    String destination = '',
    bool notifyContacts = false,
  }) async {
    if (_phase != WalkPhase.idle) return;
    _deadline = clock.now().add(duration);
    _destination = destination;
    _begin();
    await _persist();
    if (notifyContacts) await _notifyContacts();
  }

  Future<void> extend(Duration extra) async {
    if (_phase == WalkPhase.idle) return;
    final base = _phase == WalkPhase.checkIn ? clock.now() : _deadline!;
    _deadline = base.add(extra);
    _phase = WalkPhase.walking;
    await _alarm.stop();
    await _persist();
    notifyListeners();
  }

  Future<void> finish() async {
    _ticker?.cancel();
    _location.release(_holdReason);
    await _alarm.stop();
    _phase = WalkPhase.idle;
    _deadline = null;
    _destination = '';
    await _storage.saveSafeWalk(null);
    notifyListeners();
  }

  /// Continues a walk after an app restart. An overdue walk goes straight to
  /// the check-in, or to the SOS if the grace period has passed too.
  Future<void> resumeIfActive() async {
    if (_phase != WalkPhase.idle) return;
    final saved = await _storage.getSafeWalk();
    if (saved == null) return;
    _deadline = DateTime.parse(saved['deadline'] as String);
    _destination = saved['destination'] as String? ?? '';
    _begin();
  }

  void _begin() {
    _phase = WalkPhase.walking;
    _location.hold(_holdReason, background: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    _tick();
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final now = clock.now();
    if (now.isAfter(deadline.add(gracePeriod)) ||
        now.isAtSameMomentAs(deadline.add(gracePeriod))) {
      unawaited(_escalate());
    } else if (_phase == WalkPhase.walking && !now.isBefore(deadline)) {
      _phase = WalkPhase.checkIn;
      unawaited(_alarm.start());
    }
    notifyListeners();
  }

  Future<void> _escalate() async {
    await finish();
    await _emergency.triggerNow(IncidentTrigger.safeWalk);
  }

  Future<void> _notifyContacts() async {
    final contacts = await _storage.getContacts();
    final profile = await _storage.getProfile();
    final message = SosMessages.walkStarted(
      profile['name'] ?? '',
      _destination,
      _deadline!,
    );
    await Future.wait(contacts.map((c) => _sms.send(c.phone, message)));
  }

  Future<void> _persist() => _storage.saveSafeWalk({
        'deadline': _deadline!.toIso8601String(),
        'destination': _destination,
      });
}
