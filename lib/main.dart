import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/notifications/notification_navigation_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/student/student_home_shell.dart';
import 'features/student/student_message_details_screen.dart';
import 'features/student/student_notification_message_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = AppTheme.light;

    return MaterialApp(
      navigatorKey: NotificationNavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: baseTheme,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/student/home': (context) => const StudentHomeShell(),
        '/student/messages': (context) =>
            const StudentHomeShell(initialTabIndex: 2),
        '/student/sessions': (context) =>
            const StudentHomeShell(initialTabIndex: 1),
      },
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/student/message-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) =>
                StudentMessageDetailsScreen(messageId: args['messageId']),
          );
        }

        if (settings.name == '/student/notification-message') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => StudentNotificationMessageScreen(
              titleText: args['titleText']?.toString() ?? '',
              bodyText: args['bodyText']?.toString() ?? '',
            ),
          );
        }

        return null;
      },
    );
  }
}