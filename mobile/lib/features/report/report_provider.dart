import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/osm_geocoding_service.dart';
import '../../core/services/speech_to_text_provider.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';

final apiClientProvider = Provider((ref) => ApiClient());

final reportRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportRepository(apiClient);
});

final speechToTextProvider = Provider<SpeechToTextProvider>((ref) {
  return SarvamSpeechToTextProvider();
});

class ReportState {
  final String? imagePath;
  final double latitude;
  final double longitude;
  final String address;
  final String? locationMessage;
  final bool isLocating;
  final String selectedCategory;
  /// True once the citizen picked the issue type themselves (tapped a
  /// category or came in from a quick-report tile) - AI suggestions from a
  /// later photo then only advise instead of overriding their choice.
  final bool categoryChosenByUser;
  final bool isClassifyingImage;
  final String? imageClassificationMessage;
  final String? imageClassificationError;
  final String description;
  final bool isListening;
  final bool isTranscribing;
  final bool isSubmitting;
  final List<ReportModel> submittedTickets;
  final String? lastCreatedTicketId;
  final String? voiceError;
  final String? submitError;

  ReportState({
    this.imagePath,
    this.latitude = 13.0827,
    this.longitude = 77.5877,
    this.address = 'Rajanakunte, Bengaluru, Karnataka',
    this.locationMessage,
    this.isLocating = false,
    this.selectedCategory = '',
    this.categoryChosenByUser = false,
    this.isClassifyingImage = false,
    this.imageClassificationMessage,
    this.imageClassificationError,
    this.description = '',
    this.isListening = false,
    this.isTranscribing = false,
    this.isSubmitting = false,
    this.submittedTickets = const [],
    this.lastCreatedTicketId,
    this.voiceError,
    this.submitError,
  });

  ReportState copyWith({
    String? imagePath,
    double? latitude,
    double? longitude,
    String? address,
    String? locationMessage,
    bool clearLocationMessage = false,
    bool? isLocating,
    String? selectedCategory,
    bool? categoryChosenByUser,
    bool? isClassifyingImage,
    String? imageClassificationMessage,
    String? imageClassificationError,
    bool clearImageClassificationMessage = false,
    bool clearImageClassificationError = false,
    String? description,
    bool? isListening,
    bool? isTranscribing,
    bool? isSubmitting,
    List<ReportModel>? submittedTickets,
    String? lastCreatedTicketId,
    String? voiceError,
    bool clearVoiceError = false,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return ReportState(
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      locationMessage:
          clearLocationMessage ? null : locationMessage ?? this.locationMessage,
      isLocating: isLocating ?? this.isLocating,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      categoryChosenByUser: categoryChosenByUser ?? this.categoryChosenByUser,
      isClassifyingImage: isClassifyingImage ?? this.isClassifyingImage,
      imageClassificationMessage: clearImageClassificationMessage
          ? null
          : imageClassificationMessage ?? this.imageClassificationMessage,
      imageClassificationError: clearImageClassificationError
          ? null
          : imageClassificationError ?? this.imageClassificationError,
      description: description ?? this.description,
      isListening: isListening ?? this.isListening,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submittedTickets: submittedTickets ?? this.submittedTickets,
      lastCreatedTicketId: lastCreatedTicketId ?? this.lastCreatedTicketId,
      voiceError: clearVoiceError ? null : voiceError ?? this.voiceError,
      submitError: clearSubmitError ? null : submitError ?? this.submitError,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final ReportRepository repository;
  final SpeechToTextProvider speechToText;
  final ImagePicker _picker = ImagePicker();
  AudioRecorder? _audioRecorder;

  ReportNotifier(this.repository, this.speechToText) : super(ReportState()) {
    captureAutoGPS();
  }

  Future<void> captureAutoGPS() async {
    state = state.copyWith(
      isLocating: true,
      locationMessage: 'Detecting your current location...',
    );
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLocating: false,
          locationMessage:
              'Location services are off. Turn on GPS or choose the location on the map.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLocating: false,
            locationMessage:
                'Location permission denied. You can still set the issue location manually.',
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLocating: false,
          locationMessage:
              'Location permission is permanently denied. Enable it in app settings or use the map.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      await updateLocation(position.latitude, position.longitude);
      state = state.copyWith(isLocating: false, clearLocationMessage: true);
    } catch (_) {
      state = state.copyWith(
        isLocating: false,
        locationMessage:
            'Could not detect GPS right now. Check signal or choose the location on the map.',
      );
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    String addressStr =
        'Lat: ${lat.toStringAsFixed(4)}°, Lng: ${lng.toStringAsFixed(4)}°';
    try {
      addressStr = await OSMGeocodingService.reverse(lat, lng);
    } catch (_) {
      addressStr =
          'Selected Location (${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°)';
    }
    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      address: addressStr,
      isLocating: false,
      clearLocationMessage: true,
    );
  }

  void setImagePath(String path) {
    state = state.copyWith(imagePath: path);
  }

  Future<void> _classifySelectedImage(String path) async {
    state = state.copyWith(
      isClassifyingImage: true,
      imageClassificationMessage: 'Checking image with AI...',
      clearImageClassificationError: true,
    );
    try {
      final result = await repository.analyzeIssueImage(path);
      final category = result['category']?.toString();
      final label = result['label']?.toString() ?? _categoryLabel(category);
      final detected = result['detected'] == true &&
          AppConstants.isSelectableCategory(category);

      if (detected && state.categoryChosenByUser && state.selectedCategory != category) {
        state = state.copyWith(
          isClassifyingImage: false,
          imageClassificationMessage:
              'AI thinks this looks like $label. Keeping your choice - change it if needed.',
          clearImageClassificationError: true,
        );
        return;
      }

      if (detected) {
        state = state.copyWith(
          selectedCategory: category,
          isClassifyingImage: false,
          imageClassificationMessage:
              'AI detected $label. You can change it manually.',
          clearImageClassificationError: true,
        );
        return;
      }

      state = state.copyWith(
        isClassifyingImage: false,
        imageClassificationMessage:
            'AI could not confidently detect the issue type. Choose manually.',
        clearImageClassificationError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isClassifyingImage: false,
        clearImageClassificationMessage: true,
        imageClassificationError:
            'AI classification failed. Choose the issue type manually.',
      );
    }
  }

  String _categoryLabel(String? category) {
    return AppConstants.isSelectableCategory(category)
        ? AppConstants.categoryLabel(category)
        : 'Issue Type';
  }

  Future<void> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        state = state.copyWith(imagePath: image.path, clearSubmitError: true);
        await _classifySelectedImage(image.path);
      }
    } catch (_) {}
  }

  Future<void> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        state = state.copyWith(imagePath: image.path, clearSubmitError: true);
        await _classifySelectedImage(image.path);
      }
    } catch (_) {}
  }

  /// Toggle voice recording and send the captured file to the configured speech provider.
  Future<void> toggleVoice() async {
    if (state.isListening) {
      await _stopRecordingAndTranscribe();
      return;
    }

    try {
      _audioRecorder = AudioRecorder();
      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) {
        state = state.copyWith(
          voiceError:
              'Microphone permission denied. You can still type and submit the report.',
        );
        return;
      }

      final tempFile = await speechToText.createRecordingFile();
      await _audioRecorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: tempFile.path,
      );

      state = state.copyWith(isListening: true, clearVoiceError: true);
    } catch (e) {
      await _audioRecorder?.dispose();
      _audioRecorder = null;
      state = state.copyWith(
        isListening: false,
        isTranscribing: false,
        voiceError:
            'Could not start voice recording. You can still type and submit the report.',
      );
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      final path = await _audioRecorder?.stop();
      await _audioRecorder?.dispose();
      _audioRecorder = null;

      state = state.copyWith(
        isListening: false,
        isTranscribing: true,
        clearVoiceError: true,
      );

      if (path == null) {
        state = state.copyWith(
          isTranscribing: false,
          voiceError:
              'No audio was recorded. You can still type and submit the report.',
        );
        return;
      }

      final text = await speechToText.transcribe(File(path));
      final current = state.description.trim();
      final newDescription = current.isEmpty ? text : '$current $text';
      state = state.copyWith(
        description: newDescription,
        isTranscribing: false,
        clearVoiceError: true,
      );
    } on SpeechToTextException catch (e) {
      state = state.copyWith(
        isListening: false,
        isTranscribing: false,
        voiceError: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isListening: false,
        isTranscribing: false,
        voiceError:
            'Voice transcription failed. You can still type and submit the report.',
      );
    }
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    super.dispose();
  }

  /// Wipes the form back to a blank slate and re-detects GPS, matching the
  /// state the app is in the very first time it's opened. Called whenever
  /// the citizen navigates to the Report Issue screen so a previous
  /// photo/category/location/description never carries over into the next
  /// ticket.
  void resetForm({String? initialCategory}) {
    final preset = AppConstants.isSelectableCategory(initialCategory) ? initialCategory! : '';
    state = ReportState(
      selectedCategory: preset,
      categoryChosenByUser: preset.isNotEmpty,
    );
    captureAutoGPS();
  }

  void setCategory(String category) {
    state = state.copyWith(
      selectedCategory: category,
      categoryChosenByUser: true,
      clearSubmitError: true,
      imageClassificationMessage:
          'Issue type changed manually. AI suggestion will not override this choice.',
      clearImageClassificationError: true,
    );
  }

  void setDescription(String text) {
    state = state.copyWith(description: text);
  }

  Future<bool> submitFeedback({
    required String ticketId,
    required bool satisfied,
    String? comment,
  }) async {
    final ticket = state.submittedTickets.firstWhere(
      (t) => t.ticketId == ticketId,
      orElse: () => ReportModel(photoUrl: '', latitude: 0, longitude: 0, category: 'other'),
    );
    if (ticket.id == null) return false;

    try {
      final updated = await repository.submitFeedback(
        reportId: ticket.id!,
        satisfied: satisfied,
        comment: comment,
      );
      final updatedList = state.submittedTickets
          .map((t) => t.ticketId == ticketId ? updated : t)
          .toList();
      state = state.copyWith(submittedTickets: updatedList);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels a ticket the citizen no longer wants to pursue (e.g. filed by
  /// mistake). Returns null on success, or a user-facing error message.
  Future<String?> cancelTicket(String ticketId) async {
    final ticket = state.submittedTickets.firstWhere(
      (t) => t.ticketId == ticketId,
      orElse: () => ReportModel(photoUrl: '', latitude: 0, longitude: 0, category: 'other'),
    );
    if (ticket.id == null) return 'Could not find this ticket.';

    try {
      final updated = await repository.cancelReport(reportId: ticket.id!);
      final updatedList = state.submittedTickets
          .map((t) => t.ticketId == ticketId ? updated : t)
          .toList();
      state = state.copyWith(submittedTickets: updatedList);
      return null;
    } on DioException catch (e) {
      return e.response?.data?['detail']?.toString() ?? 'Could not cancel the ticket. Check your connection.';
    } catch (_) {
      return 'Could not cancel the ticket. Check your connection.';
    }
  }

  Future<void> refreshTickets({int? userId}) async {
    final reports = await repository.getReports(userId: userId);
    if (reports == null) return;
    if (reports.isNotEmpty || userId != null) {
      state = state.copyWith(submittedTickets: reports);
    }
  }

  Future<bool> submitReport({int? userId}) async {
    // The citizen's photo is the "before" evidence the worker's geo-tagged
    // "after" photo is compared against, so a report can't go without one.
    if (state.imagePath == null) {
      state = state.copyWith(submitError: 'Add a photo of the issue before submitting.');
      return false;
    }
    if (state.selectedCategory.isEmpty) {
      state = state.copyWith(submitError: 'Select the issue type before submitting.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    final String photoUrl;
    try {
      photoUrl = await repository.uploadPhoto(state.imagePath!);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Could not reach the JanSetu server to upload the photo. Check the phone is on the same Wi-Fi as the server and try again.',
      );
      return false;
    }

    final report = ReportModel(
      photoUrl: photoUrl,
      latitude: state.latitude,
      longitude: state.longitude,
      category: state.selectedCategory,
      description: state.description.trim().isEmpty
          ? '${AppConstants.categoryLabel(state.selectedCategory)} reported by citizen.'
          : state.description.trim(),
      status: 'submitted',
      createdAt: DateTime.now().toString().substring(0, 16),
    );

    final ReportModel createdReport;
    try {
      createdReport = await repository.submitReport(report, userId: userId);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitError:
            'Could not reach the JanSetu server. Check the phone is on the same Wi-Fi as the server and try again.',
      );
      return false;
    }

    final updatedList = [createdReport, ...state.submittedTickets];
    state = state.copyWith(
      isSubmitting: false,
      submittedTickets: updatedList,
      lastCreatedTicketId: createdReport.ticketId,
      imagePath: null,
      description: '',
      clearImageClassificationMessage: true,
      clearImageClassificationError: true,
    );
    return true;
  }
}

final reportNotifierProvider =
    StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  final repo = ref.watch(reportRepositoryProvider);
  final speech = ref.watch(speechToTextProvider);
  return ReportNotifier(repo, speech);
});
