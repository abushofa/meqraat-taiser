import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import 'notification_navigation_service.dart';
import '../../core/storage/session_storage.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'quran_messages_channel',
    'Quran Messages',
    description: 'Notifications for sessions and messages',
    importance: Importance.max,
  );

  static bool _initialized = false;

  static Future<void> init() async {
    try {
      if (_initialized) return;

      if (Platform.isAndroid) {
        await _initLocalNotificationsForAndroid();
        await _requestPermission();
        await _initFirebaseMessagingForAndroid();
      } else if ((Platform.isIOS || Platform.isMacOS) &&
          AppConfig.enablePushOnIOS) {
        // سنفعلها لاحقًا عندما يكون حساب Apple جاهز
      } else {
        if (kDebugMode) {
        debugPrint('Push notifications are disabled temporarily on iOS/macOS.');}
      }
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
      debugPrint('Push init error: $e');}
    }
  }

  static Future<void> _initLocalNotificationsForAndroid() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        _handleNotificationPayloadString(payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);
  }

  static Future<void> _initFirebaseMessagingForAndroid() async {
    final isLoggedIn = await SessionStorage.isLoggedIn();

    if (!isLoggedIn) return; // 🔥 حماية مهمة جدًا

    final token = await _messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _registerTokenToServer(token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      final isLoggedIn = await SessionStorage.isLoggedIn();

      if (!isLoggedIn) return; // 🔥 منع إعادة التسجيل

      await _registerTokenToServer(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showLocalNotification(
        title: message.notification?.title ?? 'إشعار جديد',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationData(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'quran_messages_channel',
      'Quran Messages',
      channelDescription: 'Notifications for sessions and messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static void _handleNotificationPayloadString(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _handleNotificationData(decoded);
      } else if (decoded is Map) {
        _handleNotificationData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // fallback قديم لو كان payload مجرد "message" أو "session"
      _handleNotificationData({'type': payload, 'target_role': 'student'});
    }
  }

static Future<void> _handleNotificationData(Map<String, dynamic> data) async {
  // 🔴 تحقق من أن المستخدم ما زال مسجل دخول
  final isLoggedIn = await SessionStorage.isLoggedIn();
  if (!isLoggedIn) return;

  final type = data['type']?.toString();
  final targetRole = data['target_role']?.toString();

  if (targetRole != 'student') return;

  final navigator = NotificationNavigationService.navigatorKey.currentState;
  if (navigator == null) return;

  if (type == 'message') {
    final messageTitle = data['message_title']?.toString() ?? '';
    final messageBody = data['message_body']?.toString() ?? '';

    navigator.pushNamedAndRemoveUntil('/student/messages', (route) => false);

    Future.delayed(const Duration(milliseconds: 300), () {
      NotificationNavigationService.navigatorKey.currentState?.pushNamed(
        '/student/notification-message',
        arguments: {
          'titleText': messageTitle,
          'bodyText': messageBody,
        },
      );
    });

    return;
  }

  if (type == 'session') {
    // 🔴 تم إلغاء Jitsi بالكامل — نستخدم Agora فقط
    NotificationNavigationService.openStudentSessions();

    navigator.pushNamedAndRemoveUntil(
      '/student/sessions',
      (route) => false,
    );
  }
}

  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  static Future<void> _registerTokenToServer(String token) async {
    try {
      final isLoggedIn = await SessionStorage.isLoggedIn();

      if (!isLoggedIn) return;

      final dio = await ApiClient.getInstance();

      await dio.post(
        '/device/register_token.php',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
    } catch (_) {
      // لا نكسر التطبيق
    }
  }
}
