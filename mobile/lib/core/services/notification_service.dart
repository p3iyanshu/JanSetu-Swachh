import 'package:firebase_messaging/firebase_messaging.dart';

import '../network/api_client.dart';

/// Registers this device's Firebase Cloud Messaging token against a
/// citizen's phone number, so the backend can push notifications when their
/// ticket is assigned/started/resolved.
///
/// Every call is wrapped defensively - if Firebase isn't initialized (no
/// google-services.json, no network, permission denied, etc.) this quietly
/// no-ops rather than blocking the citizen flow. Push notifications are a
/// nice-to-have on top of an app that must keep working without them.
class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Requests notification permission, fetches the FCM token, and registers
  /// it against [phone]. Safe to call every time a citizen logs in.
  Future<bool> registerForPhone(String phone) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token == null) return false;

      return registerDeviceToken(phone, token);
    } catch (_) {
      // Firebase not configured on this build/device - stay silent.
      return false;
    }
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
