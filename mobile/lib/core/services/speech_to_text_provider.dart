import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class SpeechToTextException implements Exception {
  final String message;

  const SpeechToTextException(this.message);

  @override
  String toString() => message;
}

abstract class SpeechToTextProvider {
  Future<File> createRecordingFile();

  Future<String> transcribe(File audioFile);
}

/// Talks to the voice-backend (Sarvam AI speech-to-text-translate).
class SarvamSpeechToTextProvider implements SpeechToTextProvider {
  static const String _configuredUrl = String.fromEnvironment(
    'JANSETU_VOICE_URL',
    defaultValue: '',
  );
  static const Duration _timeout = Duration(seconds: 30);

  SarvamSpeechToTextProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _endpoint {
    if (_configuredUrl.isNotEmpty) {
      return Uri.parse(_configuredUrl);
    }
    // The voice backend runs on the same host as the main API, just on port
    // 8001 instead of 8000 - reuse AppConstants' host resolution (which
    // already handles LAN IP for physical Android devices vs localhost for
    // web/emulator) instead of hardcoding 10.0.2.2, which only works on the
    // Android emulator and never on a real phone.
    final apiRoot = AppConstants.apiRootUrl;
    final voiceRoot = apiRoot.replaceFirst(RegExp(r':8000$'), ':8001');
    return Uri.parse('$voiceRoot/voice-to-text');
  }

  @override
  Future<File> createRecordingFile() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${dir.path}/jansetu_voice_note_$timestamp.m4a');
  }

  @override
  Future<String> transcribe(File audioFile) async {
    if (!await audioFile.exists() || await audioFile.length() == 0) {
      throw const SpeechToTextException(
        'No speech was captured. Please try again or type the description.',
      );
    }

    try {
      final request = http.MultipartRequest('POST', _endpoint)
        ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SpeechToTextException(
          'Voice transcription failed (${response.statusCode}). Type the description manually.',
        );
      }

      final decoded = jsonDecode(response.body);
      final text = decoded is Map<String, dynamic> ? decoded['text'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const SpeechToTextException(
          'No speech was detected. Please try again or type the description.',
        );
      }

      return text.trim();
    } on SpeechToTextException {
      rethrow;
    } on SocketException {
      throw const SpeechToTextException(
        'Voice service is unavailable. You can still type and submit the report.',
      );
    } on FormatException {
      throw const SpeechToTextException(
        'Voice service returned an unreadable response. Type the description manually.',
      );
    } on Exception {
      throw const SpeechToTextException(
        'Voice transcription timed out or failed. Type the description manually.',
      );
    }
  }
}
