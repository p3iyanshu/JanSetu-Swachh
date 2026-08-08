import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report_model.dart';
import '../../widgets/proof_photo_viewer.dart';
import '../../widgets/worker_ticket_card.dart';
import '../report/report_provider.dart' show apiClientProvider;
import 'worker_auth_provider.dart';
import 'worker_tickets_provider.dart';

class WorkerTicketDetailsScreen extends ConsumerStatefulWidget {
  final int reportId;
  final ReportModel? initialTicket;

  const WorkerTicketDetailsScreen({super.key, required this.reportId, this.initialTicket});

  @override
  ConsumerState<WorkerTicketDetailsScreen> createState() => _WorkerTicketDetailsScreenState();
}

class _WorkerTicketDetailsScreenState extends ConsumerState<WorkerTicketDetailsScreen> {
  ReportModel? _ticket;
  bool _isLoadingTicket = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    if (_ticket == null) {
      _fetchTicket();
    }
  }

  Future<void> _fetchTicket() async {
    setState(() => _isLoadingTicket = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/reports/${widget.reportId}');
      setState(() {
        _ticket = ReportModel.fromJson(Map<String, dynamic>.from(response.data));
        _isLoadingTicket = false;
      });
    } catch (_) {
      setState(() => _isLoadingTicket = false);
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open Google Maps.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startWork() async {
    final officer = ref.read(workerAuthProvider).officer;
    if (officer == null || _ticket == null) return;
    final updated = await ref.read(workerTicketsProvider.notifier).startWork(
          reportId: _ticket!.id!,
          officerId: officer.id,
        );
    if (updated != null) {
      setState(() => _ticket = updated);
      _showMessage('Work started. Citizen has been notified.');
    } else {
      final error = ref.read(workerTicketsProvider).actionError;
      if (error != null) _showMessage(error);
    }
  }

  Future<void> _captureProof() async {
    _showMessage('Opening camera...');
    ref.read(workerTicketsProvider.notifier).beginCapture(_ticket!.id!);
    await ref.read(workerTicketsProvider.notifier).captureCompletionPhotoAndLocation();
    final state = ref.read(workerTicketsProvider);
    if (state.capturedPhotoPath != null) {
      _showMessage(state.capturedLatitude != null
          ? 'Photo + GPS captured successfully.'
          : 'Photo captured. Getting GPS...');
    } else if (state.actionError != null) {
      _showMessage('Capture failed: ${state.actionError}');
    } else {
      _showMessage('Capture did not return a photo (no error reported).');
    }
  }

  Future<void> _retryLocation() async {
    await ref.read(workerTicketsProvider.notifier).retryLocationCapture();
  }

  Future<void> _closeTicket() async {
    final officer = ref.read(workerAuthProvider).officer;
    if (officer == null || _ticket == null) return;
    final updated = await ref.read(workerTicketsProvider.notifier).closeTicket(
          reportId: _ticket!.id!,
          officerId: officer.id,
        );
    if (updated != null) {
      setState(() => _ticket = updated);
      _showMessage('Ticket resolved. Citizen has been notified.');
    } else {
      final error = ref.read(workerTicketsProvider).actionError;
      if (error != null) _showMessage(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final officer = ref.watch(workerAuthProvider).officer;
    final ticketsState = ref.watch(workerTicketsProvider);
    final isMyCapture = ticket != null && ticketsState.capturingReportId == ticket.id;

    return Scaffold(
      appBar: AppBar(title: Text(ticket?.ticketId ?? 'Ticket Details')),
      body: ticket == null
          ? Center(child: _isLoadingTicket ? const CircularProgressIndicator() : const Text('Ticket not found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        AppConstants.resolveMediaUrl(ticket.photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ticket.ticketId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColorFor(ticket.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabelFor(ticket.status),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColorFor(ticket.status)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.category.toUpperCase().replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accentOrange),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.description?.isNotEmpty == true ? ticket.description! : 'No details provided.',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.person_outline, 'Reported by', 'Citizen'),
                  if (ticket.createdAt != null) _infoRow(Icons.event_outlined, 'Created', ticket.createdAt!),
                  if (ticket.estimatedCompletionAt != null)
                    _infoRow(Icons.schedule_outlined, 'ETA', ticket.estimatedCompletionAt!),
                  if (ticket.assignedDepartmentName != null)
                    _infoRow(Icons.apartment_outlined, 'Department', ticket.assignedDepartmentName!),
                  InkWell(
                    onTap: () => _openInMaps(ticket.latitude, ticket.longitude),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 20, color: AppTheme.accentBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${ticket.latitude.toStringAsFixed(6)}, ${ticket.longitude.toStringAsFixed(6)}  (open in Maps)',
                              style: const TextStyle(fontSize: 14, color: AppTheme.accentBlue, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.accentBlue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (ticket.status.toLowerCase() == 'assigned' &&
                      officer != null &&
                      ticket.assignedOfficerId == officer.id)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
                      onPressed: ticketsState.isLoadingAssigned ? null : _startWork,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('START WORK'),
                    ),
                  if (ticket.status.toLowerCase() == 'in_progress' &&
                      officer != null &&
                      ticket.assignedOfficerId == officer.id &&
                      ticket.adminReviewComment != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.report_gmailerrorred, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text('Admin sent this back for rework',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('"${ticket.adminReviewComment}"', style: TextStyle(color: Colors.red.shade900)),
                        ],
                      ),
                    ),
                  if ((ticket.status.toLowerCase() == 'in_progress' ||
                          ticket.status.toLowerCase() == 'reopened') &&
                      officer != null &&
                      ticket.assignedOfficerId == officer.id)
                    _buildCompletionSection(ticket, ticketsState, isMyCapture),
                  if (ticket.status.toLowerCase() == 'pending_approval')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Colors.purple.shade700),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Proof submitted. Waiting for admin to review and approve.',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade800),
                                ),
                              ),
                            ],
                          ),
                          if (ticket.latestResolutionPhotoUrl != null) ...[
                            const SizedBox(height: 10),
                            ProofPhotoLink(photoUrl: ticket.latestResolutionPhotoUrl!),
                          ],
                        ],
                      ),
                    ),
                  if (ticket.status.toLowerCase() == 'resolved')
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 10),
                              Expanded(child: Text('This ticket has been resolved.', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ),
                          if (ticket.latestResolutionPhotoUrl != null) ...[
                            const SizedBox(height: 10),
                            ProofPhotoLink(photoUrl: ticket.latestResolutionPhotoUrl!),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCompletionSection(ReportModel ticket, WorkerTicketsState ticketsState, bool isMyCapture) {
    final hasPhoto = isMyCapture && ticketsState.capturedPhotoPath != null;
    final hasLocation = isMyCapture &&
        ticketsState.capturedLatitude != null &&
        ticketsState.capturedLongitude != null &&
        ticketsState.capturedAt != null;
    final hasProof = hasPhoto && hasLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange, foregroundColor: Colors.white),
          onPressed: ticketsState.isCapturing ? null : _captureProof,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(ticketsState.isCapturing
              ? 'CAPTURING...'
              : hasPhoto
                  ? 'RETAKE COMPLETION PHOTO'
                  : 'CAPTURE COMPLETION PHOTO'),
        ),
        const SizedBox(height: 10),
        if (hasPhoto) ...[
          const Text('Captured proof photo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _fileFromPath(ticketsState.capturedPhotoPath!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 220,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (isMyCapture && ticketsState.isCapturingLocation)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Getting GPS location...', style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        else if (hasLocation)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ticket: ${ticket.ticketId}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                const SizedBox(height: 2),
                Text(
                  'Lat: ${ticketsState.capturedLatitude!.toStringAsFixed(6)}  Lng: ${ticketsState.capturedLongitude!.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Captured: ${_formatCapturedAt(ticketsState.capturedAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          )
        else if (isMyCapture && ticketsState.actionError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticketsState.actionError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                if (hasPhoto)
                  TextButton.icon(
                    onPressed: _retryLocation,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Retry GPS'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white),
          onPressed: hasProof && !ticketsState.isClosing ? _closeTicket : null,
          icon: const Icon(Icons.lock_outline),
          label: Text(ticketsState.isClosing ? 'CLOSING...' : 'CLOSE TICKET'),
        ),
      ],
    );
  }

  String _formatCapturedAt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

File _fileFromPath(String path) => File(path);
