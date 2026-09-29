import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/waste_guide_data.dart';
import '../../widgets/app_navigation_drawer.dart';
import 'swachh_providers.dart';

/// "Which Bin?" - household waste segregation guide. Fully offline (bundled
/// data); the optional AI item scan is the only part that needs the backend.
class WasteGuideScreen extends ConsumerStatefulWidget {
  const WasteGuideScreen({super.key});

  @override
  ConsumerState<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

class _WasteGuideScreenState extends ConsumerState<WasteGuideScreen> {
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  String _query = '';
  String? _streamFilter;
  bool _isScanning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanItem() async {
    final XFile? photo;
    try {
      photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1280);
    } catch (_) {
      _showMessage('Could not open the camera.');
      return;
    }
    if (photo == null) return;

    setState(() => _isScanning = true);
    try {
      final result = await ref.read(swachhRepositoryProvider).classifyWasteItem(photo.path);
      if (!mounted) return;
      final stream = wasteStreamById(result.streamId);
      if (result.detected && stream != null) {
        _showStreamSheet(stream, heading: result.message);
      } else {
        _showMessage(result.message.isEmpty ? 'Could not identify the item. Search the guide instead.' : result.message);
      }
    } catch (_) {
      _showMessage('AI scan needs an internet connection. Search the guide instead - it works offline.');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showStreamSheet(WasteStream stream, {String? heading}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null) ...[
                Text(heading, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
              ],
              _StreamHeader(stream: stream, large: true),
              const SizedBox(height: 12),
              Text(stream.summary, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              Text('Where it goes: ${stream.goesTo}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final tip in stream.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: stream.color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = searchWasteItems(_query)
        .where((item) => _streamFilter == null || item.streamId == _streamFilter)
        .toList();

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Which Bin?', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.swachhGreenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Segregate at source into 4 streams. Mixed waste can\'t be recycled or composted - it ends up in landfills.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.swachhGreen),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              for (final stream in wasteStreams)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showStreamSheet(stream),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: stream.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stream.color.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(stream.icon, color: stream.color, size: 26),
                        const Spacer(),
                        Text(stream.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: stream.color)),
                        const SizedBox(height: 2),
                        Text(stream.bin,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: AppTheme.swachhGreen,
              side: const BorderSide(color: AppTheme.swachhGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isScanning ? null : _scanItem,
            icon: _isScanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.photo_camera_outlined),
            label: Text(_isScanning ? 'Identifying item...' : 'Scan an item with AI',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search an item, e.g. battery, milk packet',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _streamFilter == null,
                  onSelected: (_) => setState(() => _streamFilter = null),
                ),
                for (final stream in wasteStreams) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(stream.name),
                    selected: _streamFilter == stream.id,
                    selectedColor: stream.color.withValues(alpha: 0.18),
                    onSelected: (selected) => setState(() => _streamFilter = selected ? stream.id : null),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No match. When unsure, keep it separate and ask your waste collector.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          for (final item in items) _WasteItemTile(item: item, onTap: () {
            final stream = wasteStreamById(item.streamId);
            if (stream != null) _showStreamSheet(stream, heading: item.name);
          }),
          const SizedBox(height: 12),
          Text(
            'Source: $wasteGuideSource',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _StreamHeader extends StatelessWidget {
  final WasteStream stream;
  final bool large;

  const _StreamHeader({required this.stream, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: large ? 24 : 16,
          backgroundColor: stream.color,
          child: Icon(stream.icon, color: Colors.white, size: large ? 26 : 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stream.name,
                  style: TextStyle(fontSize: large ? 20 : 15, fontWeight: FontWeight.w800, color: stream.color)),
              Text(stream.bin, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WasteItemTile extends StatelessWidget {
  final WasteItem item;
  final VoidCallback onTap;

  const _WasteItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = wasteStreamById(item.streamId)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(stream.icon, color: stream.color),
        title: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        subtitle: Text(item.tip, style: const TextStyle(fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: stream.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            stream.name.replaceAll(' Waste', ''),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: stream.color),
          ),
        ),
      ),
    );
  }
}
