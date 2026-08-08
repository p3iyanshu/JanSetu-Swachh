import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/photo_stamp_service.dart';
import '../../data/models/report_model.dart';
import 'worker_auth_provider.dart';

class WorkerTicketsState {
  final List<ReportModel> assignedTickets;
  final List<ReportModel> departmentTickets;
  final bool isLoadingAssigned;
  final bool isLoadingDepartment;
  final String? error;

  // Completion-proof capture state, keyed by report id being worked on.
  final int? capturingReportId;
  final String? capturedPhotoPath;
  final double? capturedLatitude;
  final double? capturedLongitude;
  final DateTime? capturedAt;
  final bool isCapturing;
  final bool isCapturingLocation;
  final bool isClosing;
  final String? actionError;

  const WorkerTicketsState({
    this.assignedTickets = const [],
    this.departmentTickets = const [],
    this.isLoadingAssigned = false,
    this.isLoadingDepartment = false,
    this.error,
    this.capturingReportId,
    this.capturedPhotoPath,
    this.capturedLatitude,
    this.capturedLongitude,
    this.capturedAt,
    this.isCapturing = false,
    this.isCapturingLocation = false,
    this.isClosing = false,
    this.actionError,
  });

  bool get hasCompletionProof =>
      capturedPhotoPath != null &&
      capturedLatitude != null &&
      capturedLongitude != null &&
      capturedAt != null;

  WorkerTicketsState copyWith({
    List<ReportModel>? assignedTickets,
    List<ReportModel>? departmentTickets,
    bool? isLoadingAssigned,
    bool? isLoadingDepartment,
    String? error,
    bool clearError = false,
    int? capturingReportId,
    bool clearCapture = false,
    String? capturedPhotoPath,
    double? capturedLatitude,
    double? capturedLongitude,
    DateTime? capturedAt,
    bool? isCapturing,
    bool? isCapturingLocation,
    bool? isClosing,
    String? actionError,
    bool clearActionError = false,
  }) {
    return WorkerTicketsState(
      assignedTickets: assignedTickets ?? this.assignedTickets,
      departmentTickets: departmentTickets ?? this.departmentTickets,
      isLoadingAssigned: isLoadingAssigned ?? this.isLoadingAssigned,
      isLoadingDepartment: isLoadingDepartment ?? this.isLoadingDepartment,
      error: clearError ? null : error ?? this.error,
      // A freshly-passed capturingReportId always wins, even if clearCapture
      // is set in the same call (beginCapture() passes both together to
      // reset old capture state while immediately starting a new one).
      capturingReportId: capturingReportId ?? (clearCapture ? null : this.capturingReportId),
      capturedPhotoPath: clearCapture ? null : capturedPhotoPath ?? this.capturedPhotoPath,
      capturedLatitude: clearCapture ? null : capturedLatitude ?? this.capturedLatitude,
      capturedLongitude: clearCapture ? null : capturedLongitude ?? this.capturedLongitude,
      capturedAt: clearCapture ? null : capturedAt ?? this.capturedAt,
      isCapturing: clearCapture ? false : isCapturing ?? this.isCapturing,
      isCapturingLocation: clearCapture ? false : isCapturingLocation ?? this.isCapturingLocation,
      isClosing: isClosing ?? this.isClosing,
      actionError: clearActionError ? null : actionError ?? this.actionError,
    );
  }
}

class WorkerTicketsNotifier extends StateNotifier<WorkerTicketsState> {
  final Ref ref;
  final ImagePicker _picker = ImagePicker();

  WorkerTicketsNotifier(this.ref) : super(const WorkerTicketsState());

  Future<void> loadAssigned(int officerId) async {
    state = state.copyWith(isLoadingAssigned: true, clearError: true);
    try {
      final tickets = await ref.read(workerRepositoryProvider).getAssignedTickets(officerId);
      state = state.copyWith(assignedTickets: tickets, isLoadingAssigned: false);
    } catch (_) {
      state = state.copyWith(
        isLoadingAssigned: false,
        error: 'Could not load your assigned tickets. Pull to retry.',
      );
    }
  }

  Future<void> loadDepartment(int departmentId) async {
    state = state.copyWith(isLoadingDepartment: true, clearError: true);
    try {
      final tickets = await ref.read(workerRepositoryProvider).getDepartmentTickets(departmentId);
      state = state.copyWith(departmentTickets: tickets, isLoadingDepartment: false);
    } catch (_) {
      state = state.copyWith(
        isLoadingDepartment: false,
        error: 'Could not load department tickets. Pull to retry.',
      );
    }
  }

  Future<ReportModel?> startWork({required int reportId, required int officerId}) async {
    try {
      final updated = await ref.read(workerRepositoryProvider).startWork(
            reportId: reportId,
            officerId: officerId,
          );
      _replaceTicketEverywhere(updated);
      return updated;
    } catch (_) {
      state = state.copyWith(actionError: 'Could not start work. Check your connection and try again.');
      return null;
    }
  }

  void beginCapture(int reportId) {
    state = state.copyWith(
      clearCapture: true,
      capturingReportId: reportId,
      clearActionError: true,
    );
  }

  /// Camera-only capture. GPS is captured by the app immediately afterward
  /// (not read from EXIF, which many Android camera intents strip or omit).
  Future<void> captureCompletionPhotoAndLocation() async {
    state = state.copyWith(isCapturing: true, clearActionError: true);
    String rawPhotoPath;
    DateTime takenAt;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) {
        state = state.copyWith(
          isCapturing: false,
          actionError: 'No photo was captured. Tap Capture Completion Photo and try again.',
        );
        return;
      }

      // Some devices return control before the camera app has finished
      // flushing the file to disk. Retry the existence/size check briefly
      // instead of failing on the very first check.
      final file = File(image.path);
      bool ready = false;
      for (var attempt = 0; attempt < 6; attempt++) {
        if (await file.exists() && await file.length() > 0) {
          ready = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (!ready) {
        state = state.copyWith(
          isCapturing: false,
          actionError:
              'The captured photo was not saved by the camera app on this device (path: ${image.path}). Try again, or check the app has camera storage permission.',
        );
        return;
      }

      // Confirm the bytes are actually readable, not just a phantom entry.
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          state = state.copyWith(
            isCapturing: false,
            actionError: 'The captured photo file is empty. Try capturing again.',
          );
          return;
        }
      } catch (e) {
        state = state.copyWith(
          isCapturing: false,
          actionError: 'Could not read the captured photo (${e.toString()}). Try again.',
        );
        return;
      }

      rawPhotoPath = image.path;
      takenAt = DateTime.now();

      // Show the raw photo immediately - it should never disappear just
      // because GPS capture (a separate step below) fails or is slow.
      state = state.copyWith(
        capturedPhotoPath: rawPhotoPath,
        capturedAt: takenAt,
        isCapturing: false,
      );
    } on PlatformException catch (e) {
      final reason = e.code == 'camera_access_denied'
          ? 'Camera permission is denied. Enable Camera access for this app in phone Settings.'
          : 'Camera error (${e.code}): ${e.message ?? 'unknown'}. Try again.';
      state = state.copyWith(isCapturing: false, actionError: reason);
      return;
    } catch (e) {
      state = state.copyWith(
        isCapturing: false,
        actionError: 'Could not capture photo (${e.toString()}). Try again.',
      );
      return;
    }

    await _captureLocation(rawPhotoPath: rawPhotoPath, capturedAt: takenAt);
  }

  Future<void> retryLocationCapture() async {
    final rawPhotoPath = state.capturedPhotoPath;
    final takenAt = state.capturedAt;
    if (rawPhotoPath == null || takenAt == null) return;
    await _captureLocation(rawPhotoPath: rawPhotoPath, capturedAt: takenAt);
  }

  Future<void> _captureLocation({required String rawPhotoPath, required DateTime capturedAt}) async {
    state = state.copyWith(isCapturingLocation: true, clearActionError: true);
    final (position, reason) = await _getCurrentPositionWithReason();
    if (position == null) {
      state = state.copyWith(isCapturingLocation: false, actionError: reason);
      return;
    }

    // Best-effort: stamp Ticket ID / Lat / Lng / Captured time onto the
    // photo itself so the geotag proof travels with the image. If stamping
    // fails for any reason, fall back to the raw photo - the metadata is
    // still submitted to the backend as separate form fields either way.
    String finalPhotoPath = rawPhotoPath;
    final reportId = state.capturingReportId;
    if (reportId != null) {
      try {
        finalPhotoPath = await PhotoStampService.stampCompletionPhoto(
          sourcePath: rawPhotoPath,
          ticketId: _ticketLabel(reportId),
          latitude: position.latitude,
          longitude: position.longitude,
          capturedAt: capturedAt,
        );
      } catch (_) {
        finalPhotoPath = rawPhotoPath;
      }
    }

    state = state.copyWith(
      capturedPhotoPath: finalPhotoPath,
      capturedLatitude: position.latitude,
      capturedLongitude: position.longitude,
      isCapturingLocation: false,
    );
  }

  String _ticketLabel(int reportId) => 'JAN-${reportId.toString().padLeft(6, '0')}';

  Future<(Position?, String?)> _getCurrentPositionWithReason() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (null, 'Location services are turned off on this device. Enable GPS/Location and try again.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return (null, 'Location permission denied. Grant location access and try again.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return (null, 'Location permission is permanently denied. Enable it from app settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return (position, null);
    } catch (_) {
      return (null, 'Could not get GPS location. Check location settings and try again.');
    }
  }

  Future<ReportModel?> closeTicket({required int reportId, required int officerId}) async {
    if (!state.hasCompletionProof) {
      state = state.copyWith(actionError: 'Capture a completion photo with GPS before closing.');
      return null;
    }
    state = state.copyWith(isClosing: true, clearActionError: true);
    try {
      final updated = await ref.read(workerRepositoryProvider).resolveTicket(
            reportId: reportId,
            officerId: officerId,
            latitude: state.capturedLatitude!,
            longitude: state.capturedLongitude!,
            photoPath: state.capturedPhotoPath!,
            capturedAt: state.capturedAt!,
          );
      _replaceTicketEverywhere(updated);
      state = state.copyWith(isClosing: false, clearCapture: true);
      return updated;
    } catch (e) {
      state = state.copyWith(
        isClosing: false,
        actionError: 'Could not close the ticket (${e.toString()}). Check your connection and try again.',
      );
      return null;
    }
  }

  void _replaceTicketEverywhere(ReportModel updated) {
    state = state.copyWith(
      assignedTickets: state.assignedTickets
          .map((t) => t.id == updated.id ? updated : t)
          .toList(),
      departmentTickets: state.departmentTickets
          .map((t) => t.id == updated.id ? updated : t)
          .toList(),
    );
  }
}

final workerTicketsProvider =
    StateNotifierProvider<WorkerTicketsNotifier, WorkerTicketsState>((ref) {
  return WorkerTicketsNotifier(ref);
});
