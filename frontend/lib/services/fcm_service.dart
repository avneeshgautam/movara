import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

const _kChannel = 'movara_admin';
const _kChannelName = 'Movara messages';
const _kChannelDesc = 'Messages from the Movara team';

const _kDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _kChannel,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  ),
  iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
);

/// Top-level handler called by FCM when the app is in the *background* or
/// *terminated*. Must be a top-level function (not a closure or method).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // flutter_local_notifications shows the notification on Android when the
  // app is backgrounded (iOS handles it natively via APNs).
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  final notification = message.notification;
  if (notification == null) return;

  await plugin.show(
    id: message.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: _kDetails,
  );
}

/// Manages Firebase Cloud Messaging for the Movara app.
///
/// Call [init] once after Firebase is initialised (in [main] or on first
/// sign-in). It:
/// 1. Requests notification permission (iOS / Android 13+).
/// 2. Registers the background message handler.
/// 3. Obtains the FCM token and sends it to the backend.
/// 4. Refreshes the token whenever FCM rotates it.
/// 5. Wires up foreground notification display via flutter_local_notifications.
class FcmService {
  FcmService(this._api);

  final ApiService _api;

  final _messaging = FirebaseMessaging.instance;
  final _localPlugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Subscriptions; cancel in dispose.
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<String>? _tokenSub;

  /// Initialise FCM. Safe to call multiple times; subsequent calls are no-ops.
  Future<void> init() async {
    // FCM on web uses the browser Push API; the service-worker approach needs
    // separate VAPID configuration, so we skip it here.
    if (kIsWeb) return;
    // Desktop (macOS, Linux, Windows) is also not supported yet.
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (_ready) return;
    _ready = true;

    // ── Permission ──────────────────────────────────────────────────────────
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // ── Local notifications plugin ──────────────────────────────────────────
    await _localPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, // already requested above
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Android 8+ requires a notification channel.
    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannel,
            _kChannelName,
            description: _kChannelDesc,
            importance: Importance.high,
            playSound: true,
          ),
        );

    // ── Background / terminated handler ─────────────────────────────────────
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // ── Foreground handler ──────────────────────────────────────────────────
    // FCM doesn't show a notification banner when the app is open; we do it
    // ourselves via flutter_local_notifications.
    _fgSub = FirebaseMessaging.onMessage.listen(_showForeground);

    // ── Token registration ──────────────────────────────────────────────────
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);

    _tokenSub = _messaging.onTokenRefresh.listen(_registerToken);
  }

  /// Show a visible notification while the app is in the foreground.
  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localPlugin.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _kDetails,
    );
  }

  /// Send (or refresh) the token to the backend so the admin can push to this
  /// device. Fire-and-forget: a failed register is retried on the next launch.
  Future<void> _registerToken(String token) async {
    try {
      await _api.registerFcmToken(token);
    } catch (_) {
      // Best-effort — the app still receives messages next time.
    }
  }

  void dispose() {
    _fgSub?.cancel();
    _tokenSub?.cancel();
  }
}
