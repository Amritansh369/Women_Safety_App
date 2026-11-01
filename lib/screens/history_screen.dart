import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/incident.dart';
import '../models/location_fix.dart';
import '../services/storage_service.dart';

/// The on-device log of past SOS alerts. Useful evidence if the user reports
/// an incident later.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = StorageService();
  List<Incident>? _incidents;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final incidents = await _storage.getIncidents();
    if (mounted) setState(() => _incidents = incidents);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This permanently deletes your SOS log.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.clearIncidents();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final incidents = _incidents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS History'),
        actions: [
          if (incidents != null && incidents.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: incidents == null
            ? const Center(child: CircularProgressIndicator())
            : incidents.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No SOS alerts yet. Any alert you send is logged here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: incidents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _IncidentCard(incident: incidents[index]),
                  ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final started = DateFormat('d MMM yyyy, HH:mm').format(incident.startedAt);
    final sent = incident.countWhere(AlertStatus.sent);
    final via = switch (incident.trigger) {
      IncidentTrigger.button => 'SOS button',
      IncidentTrigger.shake => 'Shake',
      IncidentTrigger.safeWalk => 'Missed Safe Walk check-in',
    };
    final latitude = incident.latitude;
    final longitude = incident.longitude;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(
          started,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$via. Sent to $sent of ${incident.alerts.length} contact(s).',
        ),
        trailing: latitude == null || longitude == null
            ? null
            : IconButton(
                tooltip: 'Open location',
                icon: const Icon(Icons.map_outlined),
                onPressed: () => launchUrl(
                  Uri.parse(LocationFix(
                    latitude: latitude,
                    longitude: longitude,
                    accuracy: 0,
                    time: incident.startedAt,
                  ).mapsLink),
                  mode: LaunchMode.externalApplication,
                ),
              ),
      ),
    );
  }
}
