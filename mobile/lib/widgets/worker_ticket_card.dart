import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../data/models/report_model.dart';
import 'category_icon.dart';

Color statusColorFor(String status) {
  switch (status.toLowerCase()) {
    case 'resolved':
      return Colors.green.shade700;
    case 'pending_approval':
      return Colors.purple.shade700;
    case 'in_progress':
      return Colors.orange.shade800;
    case 'assigned':
      return AppTheme.accentBlue;
    case 'reopened':
      return Colors.red.shade700;
    default:
      return Colors.blueGrey;
  }
}

String statusLabelFor(String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
      return 'IN PROGRESS';
    case 'assigned':
      return 'ASSIGNED - NOT STARTED';
    case 'pending_approval':
      return 'AWAITING ADMIN APPROVAL';
    case 'resolved':
      return 'RESOLVED';
    case 'reopened':
      return 'REOPENED';
    default:
      return status.toUpperCase();
  }
}

class WorkerTicketCard extends StatelessWidget {
  final ReportModel ticket;
  final VoidCallback onTap;

  const WorkerTicketCard({super.key, required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = statusColorFor(ticket.status);
    final label = statusLabelFor(ticket.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CategoryIcon(category: ticket.category, color: Colors.grey.shade700, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppConstants.categoryLabel(ticket.category),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (ticket.priorityScore > 0)
                    Text(
                      'Priority ${ticket.priorityScore.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket.description?.isNotEmpty == true ? ticket.description! : 'No details provided.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    icon: Icons.apartment_outlined,
                    label: ticket.assignedDepartmentName ?? 'Unassigned dept',
                  ),
                  _MetaChip(
                    icon: Icons.place_outlined,
                    label: '${ticket.latitude.toStringAsFixed(4)}, ${ticket.longitude.toStringAsFixed(4)}',
                  ),
                  if (ticket.estimatedCompletionAt != null)
                    _MetaChip(icon: Icons.schedule_outlined, label: 'ETA ${ticket.estimatedCompletionAt}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
