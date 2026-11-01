/// User-tunable safety behaviour, persisted by [StorageService].
class AppSettings {
  final int countdownSeconds;
  final bool shakeEnabled;
  final bool guardianMode; // keep shake-to-SOS alive while the app is in the background
  final bool sirenOnSos;
  final int updateIntervalMinutes;
  final String emergencyNumber;
  final String customMessage;

  const AppSettings({
    this.countdownSeconds = 5,
    this.shakeEnabled = false,
    this.guardianMode = false,
    this.sirenOnSos = false,
    this.updateIntervalMinutes = 5,
    this.emergencyNumber = '112',
    this.customMessage = '',
  });

  AppSettings copyWith({
    int? countdownSeconds,
    bool? shakeEnabled,
    bool? guardianMode,
    bool? sirenOnSos,
    int? updateIntervalMinutes,
    String? emergencyNumber,
    String? customMessage,
  }) {
    return AppSettings(
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      guardianMode: guardianMode ?? this.guardianMode,
      sirenOnSos: sirenOnSos ?? this.sirenOnSos,
      updateIntervalMinutes:
          updateIntervalMinutes ?? this.updateIntervalMinutes,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'countdownSeconds': countdownSeconds,
        'shakeEnabled': shakeEnabled,
        'guardianMode': guardianMode,
        'sirenOnSos': sirenOnSos,
        'updateIntervalMinutes': updateIntervalMinutes,
        'emergencyNumber': emergencyNumber,
        'customMessage': customMessage,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppSettings();
    return AppSettings(
      countdownSeconds:
          json['countdownSeconds'] as int? ?? defaults.countdownSeconds,
      shakeEnabled: json['shakeEnabled'] as bool? ?? defaults.shakeEnabled,
      guardianMode: json['guardianMode'] as bool? ?? defaults.guardianMode,
      sirenOnSos: json['sirenOnSos'] as bool? ?? defaults.sirenOnSos,
      updateIntervalMinutes: json['updateIntervalMinutes'] as int? ??
          defaults.updateIntervalMinutes,
      emergencyNumber:
          json['emergencyNumber'] as String? ?? defaults.emergencyNumber,
      customMessage: json['customMessage'] as String? ?? defaults.customMessage,
    );
  }
}
