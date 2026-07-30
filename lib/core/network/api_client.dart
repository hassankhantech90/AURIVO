import 'package:dio/dio.dart';

import '../services/logger_service.dart';

class ApiClient {
  ApiClient({required LoggerService logger, Dio? dio})
    : _logger = logger,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
            ),
          ) {
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => _logger.debug(object.toString()),
      ),
    );
  }

  final Dio _dio;
  final LoggerService _logger;

  Dio get dio => _dio;
}
