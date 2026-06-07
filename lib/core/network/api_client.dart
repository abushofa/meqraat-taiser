import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../notifications/notification_navigation_service.dart';
import '../storage/session_storage.dart';

class ApiClient {
  static Dio? _dio;
  static bool _showingRemoteLogoutDialog = false;

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: {"Content-Type": "application/json"},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage("${dir.path}/cookies"),
    );

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(_RemoteLogoutInterceptor());

    _dio = dio;
    return dio;
  }

  static bool get isShowingRemoteLogout => _showingRemoteLogoutDialog;
  static void setRemoteLogoutShowing(bool v) => _showingRemoteLogoutDialog = v;

  static void reset() {
    _dio = null;
    _showingRemoteLogoutDialog = false;
  }
}

class _RemoteLogoutDialog extends StatelessWidget {
  final Future<void> Function() onDismissed;
  const _RemoteLogoutDialog({required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تم تسجيل خروجك'),
      content: const Text(
        'تم تسجيل دخول حسابك من جهاز آخر.\nستنتقل إلى شاشة الدخول.',
        style: TextStyle(height: 1.6),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismissed();
          },
          child: const Text('حسناً'),
        ),
      ],
    );
  }
}

class _RemoteLogoutInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final errorData = err.response?.data;
      if (errorData is Map &&
          errorData['error'] is Map &&
          errorData['error']['logged_out_remotely'] == true) {
        _handleRemoteLogout();
      }
    }
    handler.next(err);
  }

  Future<void> _handleRemoteLogout() async {
    if (ApiClient.isShowingRemoteLogout) return;
    ApiClient.setRemoteLogoutShowing(true);

    final navigator = NotificationNavigationService.navigatorKey.currentState;
    if (navigator == null) {
      ApiClient.setRemoteLogoutShowing(false);
      return;
    }

    // نعرض الديالوج أولاً بدون async gap بين حفظ context واستخدامه
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RemoteLogoutDialog(onDismissed: () async {
          await SessionStorage.clear();
          ApiClient.reset();
          NotificationNavigationService.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (route) => false);
          ApiClient.setRemoteLogoutShowing(false);
        }),
      ),
    );
  }
}
