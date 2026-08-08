import 'package:flutter/material.dart';

import '../../widgets/app_navigation_drawer.dart';

class ContactAuthoritiesScreen extends StatelessWidget {
  const ContactAuthoritiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const contacts = [
      ('Police', '100', Icons.local_police_outlined),
      ('Fire Service', '101', Icons.local_fire_department_outlined),
      ('Ambulance', '108', Icons.medical_services_outlined),
      ('Emergency Response', '112', Icons.sos_outlined),
      ('Child Helpline', '1098', Icons.child_care_outlined),
      ('Women Helpline', '1091', Icons.woman_outlined),
      ('Road Accident Emergency', '1073', Icons.car_crash_outlined),
    ];

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'Contact Authorities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Text(
              'Use these official emergency helplines when immediate assistance is needed.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          for (final contact in contacts) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0B63CE),
                    child: Icon(contact.$3, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contact.$1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    contact.$2,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
