import 'package:flutter/material.dart';
import '../models/emergency_contact.dart';
import '../services/sos_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Lets the user fire an emergency SOS: fetches live GPS location and
/// sends it, along with a distress message, to every trusted contact.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _sosService = SosService();
  final _storage = StorageService();
  bool _sending = false;
  String? _statusMessage;
  bool _success = false;

  Future<void> _triggerSos() async {
    setState(() {
      _sending = true;
      _statusMessage = null;
    });

    try {
      final contacts = await _storage.getContacts();
      await _sosService.sendSos(contacts);
      setState(() {
        _success = true;
        _statusMessage =
            'SOS sent! Your live location was shared with ${contacts.length} trusted contact(s).';
      });
    } catch (e) {
      setState(() {
        _success = false;
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Press and hold in a real emergency.\n'
                'Your live location will be texted to all your\n'
                'trusted emergency contacts instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _sending ? null : _triggerSos,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sosRed,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sosRed.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _sending
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3)
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sos, color: Colors.white, size: 56),
                              SizedBox(height: 8),
                              Text(
                                'TAP FOR\nSOS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_success ? AppColors.success : AppColors.sosRed)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _success ? Icons.check_circle : Icons.error_outline,
                        color: _success ? AppColors.success : AppColors.sosRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color:
                                _success ? AppColors.success : AppColors.sosRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
