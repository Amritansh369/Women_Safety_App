import 'package:flutter/material.dart';

class _Section {
  final IconData icon;
  final String title;
  final List<String> tips;
  const _Section(this.icon, this.title, this.tips);
}

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static const _sections = [
    _Section(Icons.directions_walk, 'Walking alone', [
      'Stay on well-lit, busy streets, even if the route is longer.',
      'Keep one ear free of headphones and your phone out of plain view.',
      'Start a Safe Walk so someone is alerted if you do not arrive.',
    ]),
    _Section(Icons.local_taxi, 'Cabs and rides', [
      'Match the number plate and driver photo before getting in.',
      'Share your trip with a contact and sit behind the driver.',
      'Follow the route on your own map. Speak up early if it changes.',
    ]),
    _Section(Icons.nightlife, 'Going out', [
      'Tell someone where you are going and when you will be back.',
      'Keep your drink with you. Leave it behind if you lose sight of it.',
      'Use Fake Call if you want a polite way to leave.',
    ]),
    _Section(Icons.public, 'Online', [
      'Do not share your live location or address publicly.',
      'Meet new people in public, and tell a friend first.',
      'Keep screenshots of harassment. They can support a report.',
    ]),
    _Section(Icons.warning_amber, 'If you feel unsafe', [
      'Trust your instincts. You do not owe anyone politeness.',
      'Head toward people, open shops, or a police station.',
      'Make noise and draw attention. Use the SOS siren.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Tips')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final section = _sections[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                shape: const Border(),
                leading: Icon(section.icon),
                title: Text(
                  section.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tip in section.tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(tip),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
