import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/emergency_contact.dart';
import '../models/incident.dart';
import '../models/location_fix.dart';
import 'location_service.dart';
import 'siren_service.dart';
import 'sms_service.dart';
import 'sos_service.dart';
import 'storage_service.dart';

enum EmergencyPhase { idle, countdown, active }

/// Runs an SOS from countdown to "I'm safe". This is the most important code
/// in the app, and it follows two rules:
///  * Nothing may stop the alert going out. Location, siren and storage
///    failures degrade the alert; they never block it.
///  * The status shown to the user is what actually happened. An alert only
///    counts as sent once the phone network has accepted it.
class EmergencyController extends ChangeNotifier {
  EmergencyController({
    required SmsGateway sms,
    required LocationSource location,
    required StorageService storage,
    required Siren siren,
    this.firstFixTimeout = const Duration(seconds: 8),
    this.retryDelay = const Duration(seconds: 5),
    this.maxRetries = 2,
    this.autoRetryInterval = const Duration(seconds: 30),
  })  : _sms = sms,
        _location = location,
        _storage = storage,
        _siren = siren;

  static EmergencyController instance = EmergencyController(
    sms: DeviceSmsGateway(),
    location: LocationService.instance,
    storage: StorageService(),
    siren: LoopingAudio('audio/siren.wav', maximizeVolume: true),
  );

  static const _holdReason = 'emergency';

  final SmsGateway _sms;
  final LocationSource _location;
  final StorageService _storage;
  final Siren _siren;
  final Duration firstFixTimeout;
  final Duration retryDelay;
  final int maxRetries;
  final Duration autoRetryInterval;

  EmergencyPhase _phase = EmergencyPhase.idle;
  int _secondsLeft = 0;
  IncidentTrigger _trigger = IncidentTrigger.button;
  Incident? _incident;
  LocationFix? _fix;
  AppSettings _settings = const AppSettings();
  Map<String, String> _profile = const {};
  bool _dispatching = false;
  bool _needsFreshFix = false;
  Timer? _countdown;
  Timer? _updates;
  Timer? _autoRetry;
  StreamSubscription<LocationFix>? _fixSubscription;

  EmergencyPhase get phase => _phase;
  int get secondsLeft => _secondsLeft;
  Incident? get incident => _incident;
  LocationFix? get fix => _fix;
  bool get dispatching => _dispatching;
  bool get sirenOn => _siren.isPlaying;
  String get emergencyNumber => _settings.emergencyNumber;

  /// Starts the cancellable countdown. Ignored if an SOS is already running.
  Future<void> startCountdown(IncidentTrigger trigger) async {
    if (_phase != EmergencyPhase.idle) return;
    _phase = EmergencyPhase.countdown;
    _trigger = trigger;
    _secondsLeft = const AppSettings().countdownSeconds;
    notifyListeners();

    _settings = await _loadSettings();
    if (_phase != EmergencyPhase.countdown) return;
    _secondsLeft = _settings.countdownSeconds;
    notifyListeners();

    if (_secondsLeft <= 0) {
      unawaited(_activate());
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        _countdown?.cancel();
        unawaited(_activate());
      } else {
        notifyListeners();
      }
    });
  }

  void cancelCountdown() {
    if (_phase != EmergencyPhase.countdown) return;
    _countdown?.cancel();
    _phase = EmergencyPhase.idle;
    notifyListeners();
  }

  /// Skips the countdown: for a Safe Walk the user has already had a grace period.
  Future<void> triggerNow(IncidentTrigger trigger) async {
    if (_phase == EmergencyPhase.active) return;
    _countdown?.cancel();
    _trigger = trigger;
    _settings = await _loadSettings();
    await _activate();
  }

  Future<void> sendNowDuringCountdown() async {
    if (_phase != EmergencyPhase.countdown) return;
    _countdown?.cancel();
    await _activate();
  }

  Future<void> _activate() async {
    if (_phase == EmergencyPhase.active) return;
    _phase = EmergencyPhase.active;
    _dispatching = true;
    notifyListeners();

    final contacts = await _loadContacts();
    _profile = await _loadProfile();
    final incident = Incident(
      id: clock.now().microsecondsSinceEpoch.toString(),
      startedAt: clock.now(),
      trigger: _trigger,
      alerts: [
        for (final EmergencyContact c in contacts)
          ContactAlert(contactId: c.id, name: c.name, phone: c.phone),
      ],
    );
    _incident = incident;
    await _persist();
    _startMonitoring();
    if (_settings.sirenOnSos) unawaited(toggleSiren());

    final fix = await _bestAvailableFix();
    _rememberFix(fix);
    _needsFreshFix = fix == null || !fix.isFresh(clock.now());
    await _dispatch(
      incident.alerts,
      SosMessages.alert(
        name: _profile['name'] ?? '',
        bloodGroup: _profile['bloodGroup'] ?? '',
        customMessage: _settings.customMessage,
        fix: fix,
        now: clock.now(),
      ),
    );
    _dispatching = false;
    notifyListeners();

    // A position may have arrived while sending. If the user isn't moving, the
    // stream won't report again, so it has to be picked up here.
    final latest = _fix;
    if (_needsFreshFix && latest != null && latest.isFresh(clock.now())) {
      _needsFreshFix = false;
      await sendUpdate();
    }
  }

  /// Prefers a fresh fix, but gives up after [firstFixTimeout]: a late alert
  /// is worse than one with an older position.
  Future<LocationFix?> _bestAvailableFix() async {
    try {
      final fresh = await _location.currentFix(firstFixTimeout);
      return fresh ?? _fix ?? await _location.lastKnown();
    } catch (e) {
      debugPrint('Sending SOS without location: $e');
      return _fix;
    }
  }

  void _startMonitoring() {
    try {
      _fixSubscription = _location.fixes.listen(_onFix);
      _location.hold(_holdReason, background: true);
    } catch (e) {
      debugPrint('Live location unavailable during SOS: $e');
    }
    _updates = Timer.periodic(
      Duration(minutes: _settings.updateIntervalMinutes),
      (_) => unawaited(sendUpdate()),
    );
    // No signal is often temporary, and the user may be unable to tap Retry,
    // so failed alerts keep trying for as long as the SOS runs.
    _autoRetry = Timer.periodic(
      autoRetryInterval,
      (_) => unawaited(retryFailed()),
    );
  }

  void _onFix(LocationFix fix) {
    _rememberFix(fix);
    notifyListeners();
    // The first alert went out without a current position: send one the
    // moment we have it rather than waiting for the next scheduled update.
    if (_needsFreshFix && !_dispatching) {
      _needsFreshFix = false;
      unawaited(sendUpdate());
    }
  }

  void _rememberFix(LocationFix? fix) {
    if (fix == null) return;
    _fix = fix;
    _incident?.latitude = fix.latitude;
    _incident?.longitude = fix.longitude;
  }

  /// Sends [message] to [alerts] concurrently so one slow number can't delay
  /// the others, then hands anything that can't be sent directly to the composer.
  Future<void> _dispatch(List<ContactAlert> alerts, String message) async {
    final needComposer = <ContactAlert>[];
    await Future.wait(alerts.map((alert) async {
      alert.status = AlertStatus.sending;
      notifyListeners();
      final result = await _sendWithRetry(alert.phone, message);
      if (result == SmsResult.sent) {
        alert.status = AlertStatus.sent;
      } else if (result == SmsResult.failed) {
        alert.status = AlertStatus.failed;
      } else {
        needComposer.add(alert);
      }
      notifyListeners();
    }));

    if (needComposer.isNotEmpty) {
      final opened = await _sms.openComposer(
        needComposer.map((a) => a.phone).toList(),
        message,
      );
      for (final alert in needComposer) {
        alert.status = opened ? AlertStatus.composer : AlertStatus.failed;
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<SmsResult> _sendWithRetry(String phone, String message) async {
    var result = SmsResult.failed;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelay);
      try {
        result = await _sms.send(phone, message);
      } catch (e) {
        debugPrint('SMS send threw: $e');
        result = SmsResult.failed;
      }
      if (result != SmsResult.failed) break;
    }
    return result;
  }

  /// Sends the latest position to every contact whose alert got through.
  Future<void> sendUpdate() async {
    final incident = _incident;
    if (incident == null || _phase != EmergencyPhase.active) return;
    final reached =
        incident.alerts.where((a) => a.status == AlertStatus.sent).toList();
    if (reached.isEmpty) return;
    // The stream is silent while the user stands still, so ask for a new fix
    // instead of reporting an old one as "last known".
    if (_fix == null || !_fix!.isFresh(clock.now())) {
      _rememberFix(await _location.currentFix(firstFixTimeout));
    }
    final message = SosMessages.update(fix: _fix, now: clock.now());
    await Future.wait(reached.map((a) => _sendWithRetry(a.phone, message)));
    incident.updatesSent++;
    await _persist();
    notifyListeners();
  }

  /// Tries again for contacts the alert did not reach.
  Future<void> retryFailed() async {
    final incident = _incident;
    if (incident == null || _dispatching || _phase != EmergencyPhase.active) {
      return;
    }
    final failed =
        incident.alerts.where((a) => a.status == AlertStatus.failed).toList();
    if (failed.isEmpty) return;
    _dispatching = true;
    notifyListeners();
    await _dispatch(
      failed,
      SosMessages.alert(
        name: _profile['name'] ?? '',
        bloodGroup: _profile['bloodGroup'] ?? '',
        customMessage: _settings.customMessage,
        fix: _fix,
        now: clock.now(),
      ),
    );
    _dispatching = false;
    notifyListeners();
  }

  Future<void> toggleSiren() async {
    if (_siren.isPlaying) {
      await _siren.stop();
    } else {
      await _siren.start();
    }
    notifyListeners();
  }

  /// Ends the SOS, tells everyone who was alerted, and files the incident.
  Future<void> markSafe() async {
    final incident = _incident;
    if (incident == null) return;
    _stopMonitoring();
    if (_siren.isPlaying) await _siren.stop();

    final reached =
        incident.alerts.where((a) => a.status == AlertStatus.sent).toList();
    final message = SosMessages.allClear(_profile['name'] ?? '');
    await Future.wait(reached.map((a) => _sendWithRetry(a.phone, message)));

    incident.endedAt = clock.now();
    try {
      await _storage.addIncident(incident);
      await _storage.saveActiveIncident(null);
    } catch (e) {
      debugPrint('Could not file incident: $e');
    }
    _incident = null;
    _fix = null;
    _needsFreshFix = false;
    _phase = EmergencyPhase.idle;
    notifyListeners();
  }

  /// Picks an SOS back up after the app was killed while it was running.
  Future<void> resumeIfActive() async {
    if (_phase != EmergencyPhase.idle) return;
    final incident = await _storage.getActiveIncident();
    if (incident == null) return;
    _incident = incident;
    _settings = await _loadSettings();
    _profile = await _loadProfile();
    _phase = EmergencyPhase.active;
    notifyListeners();
    _startMonitoring();
    _rememberFix(await _location.currentFix(firstFixTimeout));
    await sendUpdate();
    notifyListeners();
  }

  void _stopMonitoring() {
    _updates?.cancel();
    _autoRetry?.cancel();
    _fixSubscription?.cancel();
    _fixSubscription = null;
    _location.release(_holdReason);
  }

  Future<void> _persist() async {
    try {
      await _storage.saveActiveIncident(_incident);
    } catch (e) {
      debugPrint('Could not save active incident: $e');
    }
  }

  Future<AppSettings> _loadSettings() async {
    try {
      return await _storage.getSettings();
    } catch (e) {
      debugPrint('Using default settings: $e');
      return const AppSettings();
    }
  }

  Future<Map<String, String>> _loadProfile() async {
    try {
      return await _storage.getProfile();
    } catch (e) {
      debugPrint('Sending SOS without profile: $e');
      return const {};
    }
  }

  Future<List<EmergencyContact>> _loadContacts() async {
    try {
      return await _storage.getContacts();
    } catch (e) {
      debugPrint('Could not read contacts: $e');
      return const [];
    }
  }
}
