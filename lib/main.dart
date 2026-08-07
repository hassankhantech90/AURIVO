import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/logger_service.dart';
import 'core/storage/hive_service.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = LoggerService();
  await HiveService(logger: logger).init();
  await AppSupabaseClient.initialize(logger: logger);

  runApp(const ProviderScope(child: AurivoApp()));
}
