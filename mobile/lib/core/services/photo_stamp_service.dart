import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Burns a Ticket ID / GPS coordinates / capture-time label onto a completion
/// proof photo, so the geotag proof travels with the image itself rather
/// than relying only on separately-submitted form fields.
class PhotoStampService {
  static Future<String> stampCompletionPhoto({
    required String sourcePath,
    required String ticketId,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode captured photo for stamping.');
    }

    // Keep the stamped upload a reasonable size regardless of camera resolution.
    final image = decoded.width > 1600 ? img.copyResize(decoded, width: 1600) : decoded;

    final lines = [
      'Ticket: $ticketId',
      'Lat: ${latitude.toStringAsFixed(6)}  Lng: ${longitude.toStringAsFixed(6)}',
      'Captured: ${_formatTimestamp(capturedAt)}',
    ];

    const lineHeight = 24;
    final bandHeight = lineHeight * lines.length + 16;

    img.fillRect(
      image,
      x1: 0,
      y1: image.height - bandHeight,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 170),
    );

    var y = image.height - bandHeight + 8;
    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: img.arial24,
        x: 12,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      y += lineHeight;
    }

    final outputDir = await getTemporaryDirectory();
    final safeTicketId = ticketId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final outputPath =
        '${outputDir.path}/proof_${safeTicketId}_${capturedAt.millisecondsSinceEpoch}.jpg';
    final jpegBytes = img.encodeJpg(image, quality: 88);
    await File(outputPath).writeAsBytes(jpegBytes);
    return outputPath;
  }

  static String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
