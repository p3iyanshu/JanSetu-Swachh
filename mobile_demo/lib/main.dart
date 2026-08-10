import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/models/report_model.dart';
import 'features/auth/login_screen.dart';
import 'features/home/contact_authorities_screen.dart';
import 'features/home/faq_screen.dart';
import 'features/home/home_screen.dart';
import 'features/report/report_screen.dart';
import 'features/tracking/tracking_screen.dart';
import 'features/worker/worker_auth_screen.dart';
import 'features/worker/worker_home_screen.dart';
import 'features/worker/worker_ticket_details_screen.dart';

// This single-department demo build skips Firebase/push-notification setup
// entirely (it isn't registered as its own Firebase Android client), so
// there's no init step here - see core/services/notification_service.dart.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: JanSetuApp()));
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/faq',
      builder: (context, state) => const FaqScreen(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactAuthoritiesScreen(),
    ),
    GoRoute(
      path: '/report',
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: '/tracking',
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: '/worker',
      builder: (context, state) => const WorkerAuthScreen(),
    ),
    GoRoute(
      path: '/worker/home',
      builder: (context, state) => const WorkerHomeScreen(),
    ),
    GoRoute(
      path: '/worker/ticket/:id',
      builder: (context, state) => WorkerTicketDetailsScreen(
        reportId: int.parse(state.pathParameters['id']!),
        initialTicket: state.extra as ReportModel?,
      ),
    ),
  ],
);

class JanSetuApp extends StatelessWidget {
  const JanSetuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JanSetu — Solid Waste Demo',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
