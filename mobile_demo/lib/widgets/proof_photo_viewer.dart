import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// A tappable thumbnail that opens the resolution/completion proof photo
/// full-screen. Used by the citizen tracking screen, worker ticket details,
/// and (conceptually) mirrored on the admin dashboard.
class ProofPhotoLink extends StatelessWidget {
  final String photoUrl;
  final String label;

  const ProofPhotoLink({super.key, required this.photoUrl, this.label = 'View Proof Photo'});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = AppConstants.resolveMediaUrl(photoUrl);
    return InkWell(
      onTap: () => showProofPhotoViewer(context, resolvedUrl),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              resolvedUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
          ),
          const Icon(Icons.open_in_full, size: 16),
        ],
      ),
    );
  }
}

void showProofPhotoViewer(BuildContext context, String resolvedUrl) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            child: Image.network(
              resolvedUrl,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Could not load photo.', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
