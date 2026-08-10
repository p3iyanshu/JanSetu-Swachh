import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_navigation_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'JanSetu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 165,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/images/indian_emblem.png',
                  width: 520,
                  height: 520,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Home Page',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('REPORT AN ISSUE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B63CE),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context.go('/report'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.quiz_outlined,
                        title: 'FAQ',
                        subtitle: 'How JanSetu works',
                        onTap: () => context.go('/faq'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.contact_phone_outlined,
                        title: 'Contacts',
                        subtitle: 'Emergency helplines',
                        onTap: () => context.go('/contacts'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0B63CE), size: 28),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
