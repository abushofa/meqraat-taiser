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

  // قناة الرسائل العادية
  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'quran_messages_channel',
    'رسائل القرآن',
    description: 'إشعارات الرسائل',
    importance: Importance.max,
  );

  // قناة الجلسات الفردية — صوت الأذان (res/raw/athan.wav)
  // معرّف جديد لأن Android لا يسمح بتغيير صوت قناة موجودة
  static const AndroidNotificationChannel _individualSessionChannel =
      AndroidNotificationChannel(
    'quran_sessions_athan_channel',
    'جلسات فردية',
    description: 'تنبيهات بدء الجلسات الفردية',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('athan'),
    playSound: true,
  );

  // قناة الجلسات الجماعية — صوت الأذان (نفس الصوت، قناة منفصلة للبيكند)
  static const AndroidNotificationChannel _groupSessionChannel =
      AndroidNotificationChannel(
    'quran_group_sessions_athan_channel',
    'جلسات جماعية',
    description: 'تنبيهات بدء الجلسات الجماعية',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('athan'),
    playSound: true,
  );

  static bool _initialized = false;

  static Future<void> init() async {
    try {
      if (_initialized) return;

      if (Platform.isAndroid) {
        await _initLocalNotificationsForAndroid();
        await _requestPermission();
      } else if (Platform.isIOS && AppConfig.enablePushOnIOS) {
        await _requestPermission();
        // يعرض الإشعار بالصوت حتى لو التطبيق مفتوح — iOS يتولى الأمر بدون flutter_local_notifications
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Firebase listeners تُسجَّل دائماً بغض النظر عن حالة الدخول
      await _setupFirebaseListeners();

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push init error: $e');
      }
    }
  }

  // يُستدعى مباشرة بعد تسجيل الدخول لضمان وصول الـ token للسيرفر
  static Future<void> registerTokenAfterLogin() async {
    try {
      await _tryRegisterToken();
    } catch (e) {
      if (kDebugMode) debugPrint('registerTokenAfterLogin error: $e');
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

    await androidPlugin?.createNotificationChannel(_messagesChannel);
    await androidPlugin?.createNotificationChannel(_individualSessionChannel);
    await androidPlugin?.createNotificationChannel(_groupSessionChannel);
  }

  static Future<void> _setupFirebaseListeners() async {
    await _tryRegisterToken();

    _messaging.onTokenRefresh.listen((token) async {
      final isLoggedIn = await SessionStorage.isLoggedIn();
      if (!isLoggedIn) return;
      await _registerTokenToServer(token);
    });

    // إشعار مستقبَل والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (Platform.isAndroid) {
        // Android: نعرضه يدوياً عبر flutter_local_notifications بالقناة الصحيحة
        final channelId = _resolveChannelId(message.data);
        await _showLocalNotification(
          title: message.notification?.title ?? 'إشعار جديد',
          body: message.notification?.body ?? '',
          payload: jsonEncode(message.data),
          channelId: channelId,
        );
      }
      // iOS: setForegroundNotificationPresentationOptions يتولى العرض تلقائياً
    });

    // المستخدم يضغط على الإشعار والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationData(message.data);
    });

    // التطبيق مغلق تماماً والمستخدم يضغط على الإشعار
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  // يحدد القناة المناسبة بناءً على type و session_type في الـ payload
  static String _resolveChannelId(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'session') {
      final sessionType = data['session_type']?.toString();
      return sessionType == 'group'
          ? 'quran_group_sessions_athan_channel'
          : 'quran_sessions_athan_channel';
    }
    return 'quran_messages_channel';
  }

  static Future<void> _tryRegisterToken() async {
    final isLoggedIn = await SessionStorage.isLoggedIn();
    if (!isLoggedIn) return;

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerTokenToServer(token);
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    String channelId = 'quran_messages_channel',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelDisplayName(channelId),
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static String _channelDisplayName(String channelId) {
    switch (channelId) {
      case 'quran_sessions_athan_channel':
        return 'جلسات فردية';
      case 'quran_group_sessions_athan_channel':
        return 'جلسات جماعية';
      default:
        return 'رسائل القرآن';
    }
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
      _handleNotificationData({'type': payload, 'target_role': 'student'});
    }
  }

  static Future<void> _handleNotificationData(
      Map<String, dynamic> data) async {
    final isLoggedIn = await SessionStorage.isLoggedIn();
    if (!isLoggedIn) return;

    final type = data['type']?.toString();
    final targetRole = data['target_role']?.toString();

    final navigator = NotificationNavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    // ===== مشرف =====
    if (targetRole == 'admin') {
      if (type == 'message') NotificationNavigationService.openAdminMessages();
      return;
    }

    // ===== مقريء =====
    if (targetRole == 'teacher') {
      if (type == 'message') NotificationNavigationService.openTeacherMessages();
      return;
    }

    // ===== طالب =====
    if (targetRole != 'student') return;

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
      NotificationNavigationService.openStudentSessions();
      navigator.pushNamedAndRemoveUntil('/student/sessions', (route) => false);
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
