import 'package:dio/dio.dart';

class ApiConfig {
  static String defaultBaseUrl = 'http://localhost:8085';
  static String activeBaseUrl = defaultBaseUrl;
  static String activeScenario =
      'normal'; // 'normal', 'slow', 'error', 'conflict', 'leave_reject'
}

class ApiClient {
  final Dio dio;

  ApiClient({Dio? customDio})
    : dio =
          customDio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.activeBaseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = ApiConfig.activeBaseUrl;
          if (ApiConfig.activeScenario != 'normal') {
            options.headers['X-Mock-Scenario'] = ApiConfig.activeScenario;
          }
          return handler.next(options);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    ApiConfig.activeBaseUrl = newUrl;
    dio.options.baseUrl = newUrl;
  }
}
