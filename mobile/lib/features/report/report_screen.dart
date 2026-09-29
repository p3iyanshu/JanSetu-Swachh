import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_navigation_drawer.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/location_picker_dialog.dart';
import '../auth/citizen_session_provider.dart';
import 'report_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  /// Issue type to preselect, e.g. when opened from a Swachh quick-report
  /// tile on the home screen.
  final String? initialCategory;

  const ReportScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(reportNotifierProvider.notifier)
          .resetForm(initialCategory: widget.initialCategory);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openCamera(
      BuildContext context, ReportNotifier notifier) async {
    await notifier.pickFromCamera();
  }

  Future<void> _openGallery(
      BuildContext context, ReportNotifier notifier) async {
    await notifier.pickFromGallery();
  }

  void _showPhotoSourceDialog(BuildContext context, ReportNotifier notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
              title: const Text('Take Photo (Camera)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Opens camera with flash & flip controls'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openCamera(context, notifier);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.folder_open_rounded, color: Colors.purple),
              title: const Text('Browse Files / Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Select from device storage or laptop drive'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openGallery(context, notifier);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      reportNotifierProvider.select((state) => state.description),
      (previous, next) {
        if (_descriptionController.text == next) {
          return;
        }
        _descriptionController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      },
    );

    final reportState = ref.watch(reportNotifierProvider);
    final reportNotifier = ref.read(reportNotifierProvider.notifier);

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Report an Issue',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Track Issues',
            onPressed: () => context.push('/tracking'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Photo Capture Area
            GestureDetector(
              onTap: () => _showPhotoSourceDialog(context, reportNotifier),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade400, width: 2),
                ),
                child: reportState.imagePath != null &&
                        File(reportState.imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(reportState.imagePath!),
                            fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_rounded,
                              size: 48, color: Colors.blue),
                          SizedBox(height: 8),
                          Text('TAP TO ADD PHOTO',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                          SizedBox(height: 4),
                          Text('Required: this is the "before" proof for the fix',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Category Selection
            const Text('Select Issue Type',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (reportState.isClassifyingImage ||
                reportState.imageClassificationMessage != null ||
                reportState.imageClassificationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: reportState.imageClassificationError == null
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: reportState.imageClassificationError == null
                        ? Colors.blue.shade200
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reportState.isClassifyingImage)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        reportState.imageClassificationError == null
                            ? Icons.auto_awesome
                            : Icons.info_outline,
                        size: 17,
                        color: reportState.imageClassificationError == null
                            ? Colors.blue.shade700
                            : Colors.orange.shade900,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reportState.imageClassificationError ??
                            reportState.imageClassificationMessage ??
                            'Checking image with AI...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: reportState.imageClassificationError == null
                              ? Colors.blue.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _CategorySection(
              title: 'Waste & Sanitation (Swachh)',
              color: AppTheme.swachhGreen,
              group: 'swachh',
              selectedCategory: reportState.selectedCategory,
              onSelected: reportNotifier.setCategory,
            ),
            const SizedBox(height: 14),
            _CategorySection(
              title: 'Other Civic Issues',
              color: AppTheme.accentBlue,
              group: 'civic',
              selectedCategory: reportState.selectedCategory,
              onSelected: reportNotifier.setCategory,
            ),
            if (reportState.selectedCategory == 'unsegregated_waste') ...[
              const SizedBox(height: 10),
              _GuideHint(onTap: () => context.push('/guide')),
            ],
            const SizedBox(height: 20),

            // 3. Location Box
            const Text('Issue Location',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reportState.address,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Coords: ${reportState.latitude.toStringAsFixed(4)}°, ${reportState.longitude.toStringAsFixed(4)}°',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (reportState.isLocating ||
                                reportState.locationMessage != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (reportState.isLocating)
                                    const Padding(
                                      padding:
                                          EdgeInsets.only(top: 2, right: 6),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 1, right: 4),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 15,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      reportState.locationMessage ??
                                          'Detecting your current location...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: reportState.isLocating
                                            ? Colors.blue.shade700
                                            : Colors.orange.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map_outlined,
                        size: 20, color: Colors.blue),
                    label: const Text('EDIT LOCATION ON MAP (MOVE PIN)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                    onPressed: () async {
                      final LatLng? picked =
                          await Navigator.of(context).push<LatLng>(
                        MaterialPageRoute(
                          builder: (ctx) => LocationPickerDialog(
                            initialLat: reportState.latitude,
                            initialLng: reportState.longitude,
                          ),
                        ),
                      );
                      if (picked != null) {
                        reportNotifier.updateLocation(
                            picked.latitude, picked.longitude);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Voice / Text Description
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Description (Optional)',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (reportState.isTranscribing)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.blue),
                        ),
                      ),
                    IconButton.filled(
                      tooltip: reportState.isListening
                          ? 'Stop recording'
                          : 'Record description',
                      iconSize: 24,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            reportState.isListening ? Colors.red : Colors.blue,
                      ),
                      icon: Icon(reportState.isListening
                          ? Icons.stop_rounded
                          : Icons.mic),
                      onPressed: reportState.isTranscribing
                          ? null
                          : () => reportNotifier.toggleVoice(),
                    ),
                  ],
                ),
              ],
            ),
            if (reportState.isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text('Recording audio... Tap ■ when done',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (reportState.isTranscribing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.blue),
                    ),
                    SizedBox(width: 8),
                    Text('Transcribing your voice note...',
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (reportState.voiceError != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  '⚠️ ${reportState.voiceError}',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                ),
              ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Tap mic to speak, or type here...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (text) => reportNotifier.setDescription(text),
            ),
            const SizedBox(height: 24),

            if (reportState.submitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reportState.submitError!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 5. Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: reportState.isSubmitting
                  ? null
                  : () async {
                      final success = await reportNotifier.submitReport(
                        userId: ref.read(citizenSessionProvider)?.userId,
                      );
                      final String ticketId = ref
                              .read(reportNotifierProvider)
                              .lastCreatedTicketId ??
                          '';
                      if (success && context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => TicketCreatedDialog(
                            ticketId: ticketId,
                            address: reportState.address,
                          ),
                        );
                      }
                    },
              child: reportState.isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SUBMIT REPORT',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final Color color;
  final String group;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategorySection({
    required this.title,
    required this.color,
    required this.group,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = AppConstants.categories.where((item) => item['group'] == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.05,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final category = items[index];
            final id = category['id'] as String;
            final isSelected = selectedCategory == id;
            return Semantics(
              button: true,
              selected: isSelected,
              label: '${category['label']}. ${category['hint']}',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CategoryIcon(
                        category: id,
                        size: 28,
                        color: isSelected ? color : Colors.grey.shade700,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GuideHint extends StatelessWidget {
  final VoidCallback onTap;

  const _GuideHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.swachhGreenSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.recycling_rounded, color: AppTheme.swachhGreen),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Share the "Which Bin?" guide with the household: wet, dry, sanitary and special care waste go separately.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.swachhGreen),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.swachhGreen),
          ],
        ),
      ),
    );
  }
}

class TicketCreatedDialog extends StatefulWidget {
  final String ticketId;
  final String address;

  const TicketCreatedDialog({
    super.key,
    required this.ticketId,
    required this.address,
  });

  @override
  State<TicketCreatedDialog> createState() => _TicketCreatedDialogState();
}

class _TicketCreatedDialogState extends State<TicketCreatedDialog> {
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
          context.go('/home');
        }
        return;
      }
      if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pop();
    context.go('/home');
  }

  void _viewTickets() {
    Navigator.of(context).pop();
    context.push('/tracking');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ticket Created Successfully!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Text(
              'Ticket ID: ${widget.ticketId}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Logged at ${widget.address} and routed to the department.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'Returning to Home in $_secondsLeft seconds.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0B63CE),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _goHome,
          child: const Text('RETURN HOME'),
        ),
        TextButton(
          onPressed: _viewTickets,
          child: const Text('VIEW ALL TICKETS'),
        ),
      ],
    );
  }
}
