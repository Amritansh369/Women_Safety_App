enum IncidentTrigger { button, shake, safeWalk }

/// What we actually know about an alert to one contact. `composer` means the
/// messaging app was opened: the user still had to press send, so it must
/// never be reported as delivered.
enum AlertStatus { pending, sending, sent, composer, failed }

class ContactAlert {
  final String contactId;
  final String name;
  final String phone;
  AlertStatus status;

  ContactAlert({
    required this.contactId,
    required this.name,
    required this.phone,
    this.status = AlertStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'name': name,
        'phone': phone,
        'status': status.name,
      };

  factory ContactAlert.fromJson(Map<String, dynamic> json) {
    return ContactAlert(
      contactId: json['contactId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      status: AlertStatus.values.byName(json['status'] as String),
    );
  }
}

/// One SOS, from activation to "I'm safe". Kept on-device as the user's log.
class Incident {
  final String id;
  final DateTime startedAt;
  final IncidentTrigger trigger;
  final List<ContactAlert> alerts;
  DateTime? endedAt;
  double? latitude;
  double? longitude;
  int updatesSent;

  Incident({
    required this.id,
    required this.startedAt,
    required this.trigger,
    required this.alerts,
    this.endedAt,
    this.latitude,
    this.longitude,
    this.updatesSent = 0,
  });

  int countWhere(AlertStatus status) =>
      alerts.where((a) => a.status == status).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'trigger': trigger.name,
        'alerts': alerts.map((a) => a.toJson()).toList(),
        'latitude': latitude,
        'longitude': longitude,
        'updatesSent': updatesSent,
      };

  factory Incident.fromJson(Map<String, dynamic> json) {
    final ended = json['endedAt'] as String?;
    return Incident(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: ended == null ? null : DateTime.parse(ended),
      trigger: IncidentTrigger.values.byName(json['trigger'] as String),
      alerts: (json['alerts'] as List)
          .map((a) => ContactAlert.fromJson(a as Map<String, dynamic>))
          .toList(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatesSent: json['updatesSent'] as int? ?? 0,
    );
  }
}
