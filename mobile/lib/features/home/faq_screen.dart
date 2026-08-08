import 'package:flutter/material.dart';

import '../../widgets/app_navigation_drawer.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'How do I report an issue?',
        'Tap Report an Issue, add a photo, confirm location, describe the problem, and submit.'
      ),
      (
        'Can I change the AI selected issue type?',
        'Yes. AI only suggests a category. You can manually select the correct issue type before submitting.'
      ),
      (
        'Why is precise location needed?',
        'Precise GPS helps route the ticket to the correct local authority and reduces manual follow-up.'
      ),
      (
        'Can I type instead of using voice?',
        'Yes. Voice transcription is optional, and the description field is always editable.'
      ),
    ];

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('FAQ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = items[index];
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: Text(
              item.$1,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text(item.$2),
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: items.length,
      ),
    );
  }
}
