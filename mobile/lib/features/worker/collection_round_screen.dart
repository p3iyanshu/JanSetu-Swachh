import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/swachh_repository.dart';
import '../swachh/swachh_providers.dart';
import 'worker_auth_provider.dart';

class _StatusOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _StatusOption(this.id, this.label, this.icon, this.color);
}

const _statusOptions = [
  _StatusOption('segregated', 'Segregated', Icons.check_circle_outline, Color(0xFF2E7D32)),
  _StatusOption('partial', 'Partly segregated', Icons.timelapse_rounded, Color(0xFFEF6C00)),
  _StatusOption('mixed', 'Mixed waste', Icons.cancel_outlined, Color(0xFFC62828)),
  _StatusOption('no_waste', 'No waste today', Icons.remove_circle_outline, Color(0xFF546E7A)),
  _StatusOption('not_available', 'House locked', Icons.lock_outline, Color(0xFF546E7A)),
];

_StatusOption _optionFor(String id) =>
    _statusOptions.firstWhere((option) => option.id == id, orElse: () => _statusOptions.last);

/// Door-to-door collection round: the sanitation worker records, per
/// household, whether waste was handed over segregated. Feeds the ward
/// segregation-compliance view on the admin dashboard.
class CollectionRoundScreen extends ConsumerStatefulWidget {
  const CollectionRoundScreen({super.key});

  @override
  ConsumerState<CollectionRoundScreen> createState() => _CollectionRoundScreenState();
}

class _CollectionRoundScreenState extends ConsumerState<CollectionRoundScreen> {
  static const _wardKey = 'jansetu_worker_last_ward';
  final _storage = const FlutterSecureStorage();
  final _wardController = TextEditingController();
  final _householdController = TextEditingController();
  final _noteController = TextEditingController();
  final _householdFocus = FocusNode();

  String? _status;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;
  List<CollectionLogModel> _logs = [];

  @override
  void initState() {
    super.initState();
    _restoreWard();
    Future.microtask(_loadLogs);
  }

  @override
  void dispose() {
    _wardController.dispose();
    _householdController.dispose();
    _noteController.dispose();
    _householdFocus.dispose();
    super.dispose();
  }

  Future<void> _restoreWard() async {
    try {
      final ward = await _storage.read(key: _wardKey);
      if (ward != null && mounted && _wardController.text.isEmpty) {
        _wardController.text = ward;
      }
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    final officer = ref.read(workerAuthProvider).officer;
    if (officer == null) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final logs = await ref.read(swachhRepositoryProvider).getCollections(officerId: officer.id);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load your visits. Pull down to retry.';
      });
    }
  }

  /// Best-effort location for the visit - never blocks saving.
  Future<Position?> _quickPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 6),
          );
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final officer = ref.read(workerAuthProvider).officer;
    final ward = _wardController.text.trim();
    final household = _householdController.text.trim();
    if (officer == null) return;
    if (ward.isEmpty || household.isEmpty || _status == null) {
      _showMessage('Enter the ward, the household ID and pick a status.');
      return;
    }

    setState(() => _isSaving = true);
    final position = await _quickPosition();
    try {
      final log = await ref.read(swachhRepositoryProvider).logCollection(
            householdCode: household,
            ward: ward,
            status: _status!,
            note: _noteController.text.trim(),
            latitude: position?.latitude,
            longitude: position?.longitude,
            officerId: officer.id,
          );
      try {
        await _storage.write(key: _wardKey, value: ward);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _logs = [log, ..._logs];
        _status = null;
        _householdController.clear();
        _noteController.clear();
      });
      _householdFocus.requestFocus();
      _showMessage('Saved ${log.householdCode}: ${_optionFor(log.status).label}.');
    } on DioException catch (e) {
      _showMessage(e.response?.data?['detail']?.toString() ?? 'Could not save. Check your connection.');
    } catch (_) {
      _showMessage('Could not save. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<CollectionLogModel> get _todayLogs {
    final now = DateTime.now();
    return _logs.where((log) {
      final at = log.createdAtLocal;
      return at.year == now.year && at.month == now.month && at.day == now.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final officer = ref.watch(workerAuthProvider).officer;
    if (officer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/worker'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = _todayLogs;
    final segregated = today.where((log) => log.status == 'segregated').length;
    final handedOver = today.where((log) => {'segregated', 'partial', 'mixed'}.contains(log.status)).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/worker/home'),
        ),
        title: const Text('Collection Round'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.swachhGreenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TodayStat(value: '${today.length}', label: 'Visits today'),
                  _TodayStat(value: '$segregated', label: 'Segregated'),
                  _TodayStat(
                    value: handedOver == 0 ? '-' : '${(100 * segregated / handedOver).round()}%',
                    label: 'Compliance',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wardController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Ward / area',
                hintText: 'e.g. Ward 1 - Yelahanka',
                prefixIcon: const Icon(Icons.map_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _householdController,
              focusNode: _householdFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Household ID / door number',
                hintText: 'e.g. H-045 or #12/3',
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Waste handed over', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _statusOptions)
                  ChoiceChip(
                    avatar: Icon(option.icon, size: 18, color: option.color),
                    label: Text(option.label),
                    selected: _status == option.id,
                    selectedColor: option.color.withValues(alpha: 0.16),
                    labelStyle: TextStyle(
                      fontWeight: _status == option.id ? FontWeight.w800 : FontWeight.w600,
                      color: _status == option.id ? option.color : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _status = option.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. explained segregation, gave leaflet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.swachhGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(_isSaving ? 'SAVING...' : 'SAVE VISIT'),
            ),
            const SizedBox(height: 22),
            const Text('Recent visits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_isLoading && _logs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null && _logs.isEmpty)
              Text(_loadError!, style: TextStyle(color: Colors.red.shade700))
            else if (_logs.isEmpty)
              Text('No visits logged yet.', style: TextStyle(color: Colors.grey.shade700))
            else
              for (final log in _logs.take(30)) _VisitTile(log: log),
          ],
        ),
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  final String value;
  final String label;

  const _TodayStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.swachhGreen)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
      ],
    );
  }
}

class _VisitTile extends StatelessWidget {
  final CollectionLogModel log;

  const _VisitTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final option = _optionFor(log.status);
    final at = log.createdAtLocal;
    final time =
        '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(option.icon, color: option.color),
        title: Text(log.householdCode, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${log.ward} - $time${log.note == null ? '' : '\n${log.note}'}',
          style: const TextStyle(fontSize: 13),
        ),
        isThreeLine: log.note != null,
        trailing: Text(
          option.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: option.color),
        ),
      ),
    );
  }
}
