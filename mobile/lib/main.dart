import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

/// Must be a top-level (or static) function - handles FCM messages that
/// arrive while the app is fully backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
  } catch (_) {
    // Firebase not configured/reachable - the app stays fully usable,
    // it just won't receive push notifications.
  }
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
      title: 'JanSetu',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
