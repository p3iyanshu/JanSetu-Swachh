import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/swachh_repository.dart';
import '../../widgets/app_navigation_drawer.dart';
import '../../widgets/category_icon.dart';
import '../swachh/swachh_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impact = ref.watch(citizenImpactProvider);
    final swachhCategories = AppConstants.categories
        .where((item) => item['group'] == 'swachh')
        .toList();

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(citizenImpactProvider),
        child: Stack(
          children: [
            Positioned(
              top: 165,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      'assets/images/indian_emblem.png',
                      width: 520,
                      height: 520,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Namaste!',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Spot it, snap it, get it cleaned - and track it till the job is verified.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('REPORT AN ISSUE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context.go('/report'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                impact.when(
                  data: (value) => value == null ? const SizedBox.shrink() : _ImpactCard(impact: value),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const _SectionTitle('Swachh quick report'),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: swachhCategories.length,
                  itemBuilder: (context, index) {
                    final category = swachhCategories[index];
                    final id = category['id'] as String;
                    return _QuickReportTile(
                      categoryId: id,
                      label: category['label'] as String,
                      onTap: () => context.go('/report?category=$id'),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _GuideCard(onTap: () => context.go('/guide')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.assignment_outlined,
                        title: 'My Tickets',
                        subtitle: 'Track & confirm fixes',
                        onTap: () => context.go('/tracking'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.quiz_outlined,
                        title: 'FAQ',
                        subtitle: 'How it works',
                        onTap: () => context.go('/faq'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeActionTile(
                        icon: Icons.contact_phone_outlined,
                        title: 'Contacts',
                        subtitle: 'Helplines',
                        onTap: () => context.go('/contacts'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final CitizenImpact impact;

  const _ImpactCard({required this.impact});

  @override
  Widget build(BuildContext context) {
    final nextNeeded = impact.pointsToNextLevel;
    final progress = nextNeeded == null ? 1.0 : impact.points / (impact.points + nextNeeded);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.swachhGreenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.swachhGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: AppTheme.swachhGreen, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      impact.level,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.swachhGreen),
                    ),
                    Text(
                      nextNeeded == null
                          ? 'Top level reached - thank you!'
                          : '$nextNeeded points to ${impact.nextLevelName}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${impact.points}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.swachhGreen),
                  ),
                  Text('Swachh points', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.swachhGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactStat(value: impact.reportsFiled, label: 'Reported'),
              _ImpactStat(value: impact.resolved, label: 'Fixed'),
              _ImpactStat(value: impact.verified, label: 'Verified by you'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final int value;
  final String label;

  const _ImpactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
      ],
    );
  }
}

class _QuickReportTile extends StatelessWidget {
  final String categoryId;
  final String label;
  final VoidCallback onTap;

  const _QuickReportTile({required this.categoryId, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Report $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.swachhGreenSoft,
                child: CategoryIcon(category: categoryId, size: 24, color: AppTheme.swachhGreen),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GuideCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.swachhGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.recycling_rounded, color: Colors.white, size: 36),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which Bin? Segregation Guide',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Wet, dry, sanitary or special care - search any item or scan it with AI. Works offline.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
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
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0B63CE), size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
