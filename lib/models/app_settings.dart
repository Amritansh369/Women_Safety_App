/// Languages SMS alerts can be written in, by code.
const alertLanguages = {
  'en': 'English',
  'hi': 'हिन्दी (Hindi)',
  'bn': 'বাংলা (Bengali)',
  'mr': 'मराठी (Marathi)',
  'ta': 'தமிழ் (Tamil)',
  'te': 'తెలుగు (Telugu)',
};

/// User-tunable safety behaviour, persisted by [StorageService].
class AppSettings {
  final int countdownSeconds;
  final bool shakeEnabled;
  final bool guardianMode; // keep shake-to-SOS alive while the app is in the background
  final bool sirenOnSos;
  final int updateIntervalMinutes;
  final String emergencyNumber;
  final String customMessage;
  final String language;
  final bool quickSos; // keep an SOS button in the notification shade

  const AppSettings({
    this.countdownSeconds = 5,
    this.shakeEnabled = false,
    this.guardianMode = false,
    this.sirenOnSos = false,
    this.updateIntervalMinutes = 5,
    this.emergencyNumber = '112',
    this.customMessage = '',
    this.language = 'en',
    this.quickSos = false,
  });

  AppSettings copyWith({
    int? countdownSeconds,
    bool? shakeEnabled,
    bool? guardianMode,
    bool? sirenOnSos,
    int? updateIntervalMinutes,
    String? emergencyNumber,
    String? customMessage,
    String? language,
    bool? quickSos,
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
      language: language ?? this.language,
      quickSos: quickSos ?? this.quickSos,
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
        'language': language,
        'quickSos': quickSos,
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
      language: json['language'] as String? ?? defaults.language,
      quickSos: json['quickSos'] as bool? ?? defaults.quickSos,
    );
  }
}
