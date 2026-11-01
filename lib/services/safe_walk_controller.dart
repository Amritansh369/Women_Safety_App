import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident.dart';
import '../models/location_fix.dart';
import '../strings.dart';
import 'device_events.dart';
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
    this.arrivalRadiusMetres = 75,
    this.arrivalDwell = const Duration(seconds: 30),
    this.lowBatteryLevel = 10,
    this.batteryCheckInterval = const Duration(minutes: 1),
    Future<int?> Function()? batteryLevel,
    void Function()? onArrived,
  })  : _emergency = emergency,
        _location = location,
        _storage = storage,
        _sms = sms,
        _alarm = alarm,
        _batteryLevel = batteryLevel ?? _noBattery,
        _onArrived = onArrived;

  static final instance = SafeWalkController(
    emergency: EmergencyController.instance,
    location: LocationService.instance,
    storage: StorageService(),
    sms: DeviceSmsGateway(),
    alarm: LoopingAudio('audio/siren.wav', maximizeVolume: true),
    batteryLevel: DeviceEvents.batteryLevel,
    onArrived: () => unawaited(
      DeviceEvents.postNotice(
        tr('You have arrived'),
        tr('Your Safe Walk has ended.'),
      ),
    ),
  );

  static const _holdReason = 'safe_walk';
  static const _worstArrivalAccuracy = 100.0; // metres
  static Future<int?> _noBattery() async => null;

  final EmergencyController _emergency;
  final LocationSource _location;
  final StorageService _storage;
  final SmsGateway _sms;
  final Siren _alarm;
  final Future<int?> Function() _batteryLevel;
  final void Function()? _onArrived;
  final Duration gracePeriod;
  final double arrivalRadiusMetres;
  final Duration arrivalDwell;
  final int lowBatteryLevel;
  final Duration batteryCheckInterval;

  WalkPhase _phase = WalkPhase.idle;
  DateTime? _deadline;
  String _destination = '';
  LatLng? _arrivalPoint;
  bool _contactsTold = false;
  bool _lowBatterySent = false;
  DateTime? _insideSince;
  DateTime? _lastBatteryCheck;
  LocationFix? _fix;
  Timer? _ticker;
  StreamSubscription<LocationFix>? _fixSubscription;

  WalkPhase get phase => _phase;
  DateTime? get deadline => _deadline;
  String get destination => _destination;
  bool get detectsArrival => _arrivalPoint != null;

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
    LatLng? arrivalPoint,
  }) async {
    if (_phase != WalkPhase.idle) return;
    _deadline = clock.now().add(duration);
    _destination = destination;
    _arrivalPoint = arrivalPoint;
    _contactsTold = notifyContacts;
    _lowBatterySent = false;
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
    _fixSubscription?.cancel();
    _fixSubscription = null;
    _location.release(_holdReason);
    await _alarm.stop();
    _phase = WalkPhase.idle;
    _deadline = null;
    _destination = '';
    _arrivalPoint = null;
    _insideSince = null;
    _fix = null;
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
    final latitude = (saved['latitude'] as num?)?.toDouble();
    final longitude = (saved['longitude'] as num?)?.toDouble();
    _arrivalPoint = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
    _contactsTold = saved['contactsTold'] as bool? ?? false;
    _lowBatterySent = saved['lowBatterySent'] as bool? ?? false;
    _begin();
  }

  void _begin() {
    _phase = WalkPhase.walking;
    _fixSubscription = _location.fixes.listen(_onFix);
    _location.hold(_holdReason, background: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    _tick();
  }

  void _onFix(LocationFix fix) {
    _fix = fix;
    final point = _arrivalPoint;
    if (point == null) return;
    final distance = const Distance()
        .as(LengthUnit.Meter, LatLng(fix.latitude, fix.longitude), point);
    // A vague fix could place the user at the door while they're streets away.
    if (distance <= arrivalRadiusMetres &&
        fix.accuracy <= _worstArrivalAccuracy) {
      _insideSince ??= clock.now();
    } else {
      _insideSince = null;
    }
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final now = clock.now();
    final inside = _insideSince;
    if (inside != null && now.difference(inside) >= arrivalDwell) {
      unawaited(_arrive());
      return;
    }
    if (now.isAfter(deadline.add(gracePeriod)) ||
        now.isAtSameMomentAs(deadline.add(gracePeriod))) {
      unawaited(_escalate());
    } else if (_phase == WalkPhase.walking && !now.isBefore(deadline)) {
      _phase = WalkPhase.checkIn;
      unawaited(_alarm.start());
    }
    final checked = _lastBatteryCheck;
    if (!_lowBatterySent &&
        (checked == null || now.difference(checked) >= batteryCheckInterval)) {
      _lastBatteryCheck = now;
      unawaited(_checkBattery());
    }
    notifyListeners();
  }

  Future<void> _arrive() async {
    final told = _contactsTold;
    await finish();
    _onArrived?.call();
    if (!told) return;
    final profile = await _storage.getProfile();
    final settings = await _storage.getSettings();
    await _sendToContacts(SosMessages.walkArrived(
      profile['name'] ?? '',
      language: settings.language,
    ));
  }

  Future<void> _escalate() async {
    final destination = _destination;
    await finish();
    await _emergency.triggerNow(
      IncidentTrigger.safeWalk,
      destination: destination,
    );
  }

  /// Warns contacts once, while there's still battery left to do it. If nobody
  /// could be reached the next check tries again.
  Future<void> _checkBattery() async {
    final level = await _batteryLevel();
    if (level == null || level > lowBatteryLevel || _lowBatterySent) return;
    _lowBatterySent = true;
    final fix = _fix ?? await _location.currentFix(const Duration(seconds: 8));
    if (_phase == WalkPhase.idle) return;
    final profile = await _storage.getProfile();
    final settings = await _storage.getSettings();
    final reached = await _sendToContacts(SosMessages.lowBattery(
      name: profile['name'] ?? '',
      level: level,
      fix: fix,
      now: clock.now(),
      language: settings.language,
    ));
    _lowBatterySent = reached;
    if (_phase != WalkPhase.idle) await _persist();
  }

  Future<void> _notifyContacts() async {
    final profile = await _storage.getProfile();
    final settings = await _storage.getSettings();
    await _sendToContacts(SosMessages.walkStarted(
      profile['name'] ?? '',
      _destination,
      _deadline!,
      language: settings.language,
    ));
  }

  /// Returns whether at least one contact was reached.
  Future<bool> _sendToContacts(String message) async {
    final contacts = await _storage.getContacts();
    final results =
        await Future.wait(contacts.map((c) => _sms.send(c.phone, message)));
    return results.contains(SmsResult.sent);
  }

  Future<void> _persist() => _storage.saveSafeWalk({
        'deadline': _deadline!.toIso8601String(),
        'destination': _destination,
        'latitude': _arrivalPoint?.latitude,
        'longitude': _arrivalPoint?.longitude,
        'contactsTold': _contactsTold,
        'lowBatterySent': _lowBatterySent,
      });
}
