import 'package:hive_flutter/hive_flutter.dart';

import '../services/logger_service.dart';

class HiveService {
  HiveService({required LoggerService logger}) : _logger = logger;

  final LoggerService _logger;

  Future<void> init() async {
    await Hive.initFlutter();
    _logger.info('Hive initialized');
  }

  Future<Box<T>> openBox<T>(String name) => Hive.openBox<T>(name);
}
