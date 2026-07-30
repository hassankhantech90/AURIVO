import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/hive_service.dart';
import '../storage/secure_storage_service.dart';
import 'connectivity_service.dart';
import 'logger_service.dart';

final loggerServiceProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(logger: ref.watch(loggerServiceProvider));
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).dio;
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final hiveServiceProvider = Provider<HiveService>((ref) {
  return HiveService(logger: ref.watch(loggerServiceProvider));
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});
