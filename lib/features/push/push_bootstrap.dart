import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';
import '../authentication/providers/session_provider.dart';
import '../notifications/providers/notification_providers.dart';
import 'providers/push_providers.dart';

/// Wraps the app (mounted in `main()` only) and wires push as a delivery layer
/// over the canonical notifications system: registers the device on an
/// authenticated session, re-registers on token refresh, unregisters this
/// installation on logout, refreshes the in-app centre on foreground messages,
/// and routes notification taps through the existing GoRouter. It is inert when
/// Firebase is not initialized (e.g. widget tests), and Android-only. FCM tokens
/// and payload bodies are never logged.
class PushBootstrap extends ConsumerStatefulWidget {
  const PushBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends ConsumerState<PushBootstrap> {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'aurivo_default',
    'AURIVO notifications',
    importance: Importance.high,
  );

  bool _messagingReady = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (Firebase.apps.isEmpty) return; // not configured (tests / other envs)
    } catch (_) {
      return;
    }
    try {
      await _setupMessaging();
      _messagingReady = true;
      if (ref.read(sessionProvider).isAuthenticated) {
        await _register();
      }
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial);
    } catch (_) {
      // Push is best-effort; never break app startup.
    }
  }

  Future<void> _setupMessaging() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _openRoute(payload);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _register() async {
    if (_registered) return;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return; // cannot register without a token
    await ref
        .read(pushRegistrarProvider)
        .register(
          token: token,
          permissionStatus: _mapPermission(settings.authorizationStatus),
        );
    _registered = true;
  }

  Future<void> _onTokenRefresh(String token) async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      await ref
          .read(pushRegistrarProvider)
          .register(
            token: token,
            permissionStatus: _mapPermission(settings.authorizationStatus),
          );
    } catch (_) {
      // best-effort refresh
    }
  }

  void _onForeground(RemoteMessage message) {
    // Refresh the canonical in-app centre; do not duplicate read state locally.
    ref.read(notificationsProvider.notifier).load();
    final notification = message.notification;
    if (notification != null) {
      _local.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: _payloadFrom(message),
      );
    }
  }

  void _handleTap(RemoteMessage message) => _openRoute(_payloadFrom(message));

  String _payloadFrom(RemoteMessage message) {
    final route = message.data['route'] ?? '';
    final id = message.data['notification_id'] ?? '';
    return '$route|$id';
  }

  void _openRoute(String payload) {
    final parts = payload.split('|');
    final route = parts.isNotEmpty ? parts[0] : '';
    final id = parts.length > 1 ? parts[1] : '';
    if (route.isNotEmpty) {
      ref.read(appRouterProvider).push(route);
    }
    if (id.isNotEmpty) {
      // Tapping marks only that one canonical notification read.
      ref.read(notificationsProvider.notifier).markRead(id);
    }
  }

  String _mapPermission(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'granted';
      case AuthorizationStatus.provisional:
        return 'provisional';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.notDetermined:
        return 'not_determined';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register on login, unregister this installation on logout.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (!_messagingReady) return;
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      if (!wasAuthenticated && next.isAuthenticated) {
        _register();
      } else if (wasAuthenticated && !next.isAuthenticated) {
        _registered = false;
        ref.read(pushRegistrarProvider).unregister();
      }
    });
    return widget.child;
  }
}
