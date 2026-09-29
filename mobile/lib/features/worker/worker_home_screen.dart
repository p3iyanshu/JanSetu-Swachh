import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/report_model.dart';
import '../../widgets/worker_ticket_card.dart';
import 'worker_auth_provider.dart';
import 'worker_tickets_provider.dart';

enum _WorkerView { assigned, department }

class WorkerHomeScreen extends ConsumerStatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  ConsumerState<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends ConsumerState<WorkerHomeScreen> {
  _WorkerView _view = _WorkerView.assigned;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final officer = ref.read(workerAuthProvider).officer;
    if (officer == null) return;
    final notifier = ref.read(workerTicketsProvider.notifier);
    if (_view == _WorkerView.assigned) {
      await notifier.loadAssigned(officer.id);
    } else {
      await notifier.loadDepartment(officer.departmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(workerAuthProvider);
    final officer = authState.officer;

    if (officer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/worker'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ticketsState = ref.watch(workerTicketsProvider);
    final tickets = _view == _WorkerView.assigned ? ticketsState.assignedTickets : ticketsState.departmentTickets;
    final isLoading = _view == _WorkerView.assigned ? ticketsState.isLoadingAssigned : ticketsState.isLoadingDepartment;

    return Scaffold(
      appBar: AppBar(
        title: Text(_view == _WorkerView.assigned ? 'My Assigned Tickets' : 'All Department Tickets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: _buildDrawer(officer.name, officer.empId ?? '', _isSanitationWorker(authState, officer.departmentId)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(isLoading, tickets, ticketsState.error),
      ),
    );
  }

  Widget _buildBody(bool isLoading, List<ReportModel> tickets, String? error) {
    if (isLoading && tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && tickets.isEmpty) {
      return _buildMessage(icon: Icons.error_outline, message: error, showRetry: true);
    }
    if (tickets.isEmpty) {
      return _buildMessage(
        icon: Icons.assignment_turned_in_outlined,
        message: _view == _WorkerView.assigned
            ? 'No tickets assigned to you yet.'
            : 'No tickets for your department yet.',
        showRetry: false,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return WorkerTicketCard(
          ticket: ticket,
          onTap: () => context.push('/worker/ticket/${ticket.id}', extra: ticket),
        );
      },
    );
  }

  Widget _buildMessage({required IconData icon, required String message, required bool showRetry}) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ),
        ),
        if (showRetry) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
          ),
        ],
      ],
    );
  }

  /// Door-to-door collection rounds only make sense for the waste /
  /// sanitation department. If departments haven't loaded yet, show it
  /// rather than hide a feature the worker may need.
  bool _isSanitationWorker(WorkerAuthState authState, int departmentId) {
    final matches = authState.departments.where((department) => department.id == departmentId);
    if (matches.isEmpty) return true;
    final name = matches.first.name.toLowerCase();
    return name.contains('waste') || name.contains('sanitation') || name.contains('garbage');
  }

  Widget _buildDrawer(String name, String empId, bool showCollectionRound) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: AppTheme.primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.engineering_outlined, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'JanSetu-Swachh Worker',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('$name (${empId.isEmpty ? "-" : empId})', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('My Assigned Tickets'),
              selected: _view == _WorkerView.assigned,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _view = _WorkerView.assigned);
                _refresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('All Department Tickets'),
              selected: _view == _WorkerView.department,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _view = _WorkerView.department);
                _refresh();
              },
            ),
            if (showCollectionRound)
              ListTile(
                leading: const Icon(Icons.recycling_rounded, color: AppTheme.swachhGreen),
                title: const Text('Door-to-door Collection'),
                subtitle: const Text('Log household segregation'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/worker/collection');
                },
              ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(workerAuthProvider.notifier).logout();
                if (mounted) context.go('/worker');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
