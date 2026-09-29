import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/swachh_repository.dart';
import '../auth/citizen_session_provider.dart';
import '../report/report_provider.dart' show apiClientProvider;

final swachhRepositoryProvider = Provider((ref) {
  return SwachhRepository(ref.watch(apiClientProvider));
});

/// The signed-in citizen's Swachh points, or null when nobody is signed in
/// (offline demo fallback). Refresh with `ref.invalidate(citizenImpactProvider)`.
final citizenImpactProvider = FutureProvider.autoDispose<CitizenImpact?>((ref) async {
  final session = ref.watch(citizenSessionProvider);
  if (session == null) return null;
  return ref.watch(swachhRepositoryProvider).getCitizenImpact(session.userId);
});
