import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/logger_service.dart';
import 'core/storage/hive_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/push/push_bootstrap.dart';
import 'features/push/services/push_background_handler.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);

  final logger = LoggerService();
  await HiveService(logger: logger).init();
  await AppSupabaseClient.initialize(logger: logger);

  runApp(const ProviderScope(child: PushBootstrap(child: AurivoApp())));
}
