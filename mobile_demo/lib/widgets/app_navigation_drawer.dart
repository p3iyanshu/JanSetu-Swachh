import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
                    'JanSetu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
              title: const Text('View Tickets'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/tracking');
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
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Single-department demo — Solid Waste only',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
