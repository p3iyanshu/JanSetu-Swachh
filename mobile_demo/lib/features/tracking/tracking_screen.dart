import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/report_model.dart';
import '../../widgets/app_navigation_drawer.dart';
import '../../widgets/proof_photo_viewer.dart';
import '../report/report_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(reportNotifierProvider.notifier).refreshTickets();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green.shade700;
      case 'pending_approval':
        return Colors.purple.shade700;
      case 'in_progress':
        return Colors.orange.shade800;
      case 'assigned':
        return Colors.indigo.shade600;
      case 'reopened':
        return Colors.red.shade700;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade700;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'assigned':
        return 'ASSIGNED';
      case 'pending_approval':
        return 'UNDER REVIEW';
      case 'resolved':
        return 'RESOLVED';
      case 'reopened':
        return 'REOPENED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'SUBMITTED';
    }
  }

  static const Set<String> _cancellableStatuses = {
    'submitted',
    'assigned',
    'in_progress',
    'pending_approval',
    'reopened',
  };

  void _showTicketDetails(BuildContext context, ReportModel ticket) {
    final resolvedPhotoUrl = AppConstants.resolveMediaUrl(ticket.photoUrl);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ticket.ticketId,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(ticket.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatStatusLabel(ticket.status),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(ticket.status)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => showProofPhotoViewer(context, resolvedPhotoUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    resolvedPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Tap photo to view full screen',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.build_circle_outlined, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 6),
                Text(
                  ticket.category.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              (ticket.description == null || ticket.description!.isEmpty)
                  ? 'No details provided.'
                  : ticket.description!,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            Text(
              'Coords: ${ticket.latitude.toStringAsFixed(4)}°, ${ticket.longitude.toStringAsFixed(4)}°',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (ticket.createdAt != null) ...[
              const SizedBox(height: 4),
              Text('Reported on: ${ticket.createdAt}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
            if (ticket.assignedOfficerName != null) ...[
              const SizedBox(height: 10),
              Text(
                'Assigned to: ${ticket.assignedOfficerName} (${ticket.assignedOfficerEmpId ?? 'Emp ID pending'})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange.shade900),
              ),
            ],
            if (ticket.latestResolutionPhotoUrl != null) ...[
              const SizedBox(height: 14),
              const Text('Resolution Proof', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 8),
              ProofPhotoLink(photoUrl: ticket.latestResolutionPhotoUrl!),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportNotifierProvider);
    final reportNotifier = ref.read(reportNotifierProvider.notifier);
    final tickets = reportState.submittedTickets;

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Track Civic Tickets',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => reportNotifier.refreshTickets(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tickets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tickets reported yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final statusColor = _getStatusColor(ticket.status);
                final statusLabel = _formatStatusLabel(ticket.status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showTicketDetails(context, ticket),
                    child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                ticket.ticketId,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.build_circle_outlined, color: Colors.grey.shade700, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              ticket.category.toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.description ?? 'No details provided.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                        if (ticket.createdAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reported on: ${ticket.createdAt}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                        if (ticket.assignedOfficerName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Assigned to: ${ticket.assignedOfficerName} (${ticket.assignedOfficerEmpId ?? 'Emp ID pending'})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                        if (ticket.estimatedCompletionAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Estimated completion: ${ticket.estimatedCompletionAt}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                        if (ticket.status.toLowerCase() == 'resolved') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Resolved by ${ticket.assignedOfficerName ?? 'assigned employee'}'
                            '${ticket.assignedOfficerEmpId == null ? '' : ' (${ticket.assignedOfficerEmpId})'}'
                            '${ticket.resolvedAt == null ? '' : ' on ${ticket.resolvedAt}'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                          if (ticket.latestResolutionPhotoUrl != null) ...[
                            const SizedBox(height: 8),
                            ProofPhotoLink(photoUrl: ticket.latestResolutionPhotoUrl!),
                          ],
                        ],
                        if (ticket.status.toLowerCase() == 'resolved' && !ticket.citizenVerified) ...[
                          const SizedBox(height: 12),
                          _FeedbackSection(ticketId: ticket.ticketId),
                        ],
                        if (ticket.status.toLowerCase() == 'resolved' && ticket.citizenVerified) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 18, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text('Verified by you', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            ],
                          ),
                        ],
                        if (ticket.status.toLowerCase() == 'reopened') ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You marked this unresolved. The worker needs to fix it again.',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                                ),
                                if (ticket.citizenFeedbackComment?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text('Your comment: ${ticket.citizenFeedbackComment}', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (ticket.status.toLowerCase() == 'cancelled') ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'You cancelled this ticket.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_cancellableStatuses.contains(ticket.status.toLowerCase())) ...[
                          const SizedBox(height: 12),
                          _CancelTicketButton(ticketId: ticket.ticketId),
                        ],
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _FeedbackSection extends ConsumerStatefulWidget {
  final String ticketId;

  const _FeedbackSection({required this.ticketId});

  @override
  ConsumerState<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends ConsumerState<_FeedbackSection> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool satisfied) async {
    setState(() => _isSubmitting = true);
    final success = await ref.read(reportNotifierProvider.notifier).submitFeedback(
          ticketId: widget.ticketId,
          satisfied: satisfied,
          comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit feedback. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Are you satisfied with the resolution?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _commentController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Optional comment',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: _isSubmitting ? null : () => _submit(true),
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                label: const Text('Satisfied'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: _isSubmitting ? null : () => _submit(false),
                icon: const Icon(Icons.thumb_down_alt_outlined, size: 16),
                label: const Text('Not Satisfied'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CancelTicketButton extends ConsumerStatefulWidget {
  final String ticketId;

  const _CancelTicketButton({required this.ticketId});

  @override
  ConsumerState<_CancelTicketButton> createState() => _CancelTicketButtonState();
}

class _CancelTicketButtonState extends ConsumerState<_CancelTicketButton> {
  bool _isCancelling = false;

  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this ticket?'),
        content: const Text(
          'This will close the ticket permanently. Use this if you reported it by mistake or it no longer needs attention.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Ticket'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Ticket', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    final error = await ref.read(reportNotifierProvider.notifier).cancelTicket(widget.ticketId);
    if (!mounted) return;
    setState(() => _isCancelling = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade200),
        ),
        onPressed: _isCancelling ? null : _confirmAndCancel,
        icon: _isCancelling
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close_rounded, size: 16),
        label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Ticket'),
      ),
    );
  }
}
