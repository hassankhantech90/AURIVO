import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../firebase_options.dart';

/// Top-level FCM background handler (required registration for firebase_messaging).
/// Display notifications are rendered by the system tray; the canonical record
/// already lives in `public.notifications`, so this handler intentionally does no
/// heavy work and never logs message content.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // No-op body: the system displays the notification; tap handling and read
  // state are reconciled when the app opens.
}
