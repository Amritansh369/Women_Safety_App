import 'package:flutter/material.dart';
import '../services/sos_service.dart';
import '../theme.dart';

class _Helpline {
  final String name;
  final String number;
  final String detail;
  const _Helpline(this.name, this.number, this.detail);
}

/// National helplines for India, one tap to dial. Calls open the phone's dialer.
class HelplinesScreen extends StatelessWidget {
  const HelplinesScreen({super.key});

  static const _helplines = [
    _Helpline('Emergency', '112', 'Police, fire and ambulance'),
    _Helpline('Women Helpline', '1091', 'Women in distress'),
    _Helpline('Women Helpline', '181', 'Domestic abuse and support'),
    _Helpline('Police', '100', 'Local police'),
    _Helpline('Ambulance', '108', 'Medical emergencies'),
    _Helpline('Cyber Crime', '1930', 'Online fraud and harassment'),
    _Helpline('Child Helpline', '1098', 'Children in need of help'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Helplines (India)')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _helplines.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final line = _helplines[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => callNumber(line.number),
                title: Text(
                  line.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(line.detail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.call, color: AppColors.success),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
