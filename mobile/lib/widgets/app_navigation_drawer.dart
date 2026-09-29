import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/citizen_session_provider.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(citizenSessionProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF0F172A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/indian_emblem.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+91 ${session.phone}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home Page'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Report an Issue'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/report');
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('My Tickets'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/tracking');
              },
            ),
            ListTile(
              leading: const Icon(Icons.recycling_rounded),
              title: const Text('Which Bin? Guide'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/guide');
              },
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('FAQ'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/faq');
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('Contact Authorities'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/contacts');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(citizenSessionProvider.notifier).logout();
                if (context.mounted) context.go('/');
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Clean & Green civic action - SIH 2026',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
