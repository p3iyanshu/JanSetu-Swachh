import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Re-read the base URL on every request so a server address changed in
    // the app's settings applies immediately to every client instance.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = AppConstants.apiBaseUrl;
          handler.next(options);
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }
}
