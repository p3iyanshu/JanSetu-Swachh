import '../network/api_client.dart';

/// In the full app this registers a Firebase Cloud Messaging token so the
/// backend can push notifications. This single-department demo build has no
/// Firebase client registered, so it stays a no-op - the citizen flow works
/// identically either way, it just never receives a push.
class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  Future<bool> registerForPhone(String phone) async {
    return false;
  }

  Future<bool> registerDeviceToken(String phone, String fcmToken) async {
    try {
      await _apiClient.dio.post(
        '/auth/register-device-token',
        data: {'phone': phone, 'fcm_token': fcmToken},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
