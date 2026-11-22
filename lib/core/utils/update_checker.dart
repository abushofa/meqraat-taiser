import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../notifications/notification_navigation_service.dart';

/// فحص وجود إصدار أحدث (version.php).
/// يُستدعى من صفحة الدخول، والصفحات الرئيسية (طالب/مقرئ/مشرف)، وعند عودة التطبيق من الخلفية.
/// نافذة واحدة فقط في كل مرة، ولا يتكرر الفحص خلال دقيقتين.
class UpdateChecker {
  static bool _busy = false;
  static bool _dialogOpen = false;
  static DateTime? _lastCheck;

  /// [context] غير مطلوب: النافذة تُعرض فوق أي صفحة مفتوحة
  static Future<void> check([BuildContext? context]) async {
    if (_busy || _dialogOpen) return;
    final now = DateTime.now();
    if (_lastCheck != null && now.difference(_lastCheck!) < const Duration(minutes: 2)) {
      return;
    }
    _busy = true;
    _lastCheck = now;
    try {
      final res = await Dio().get('https://taiser.net/Quran/api/version.php');
      final data = res.data;
      if (data is! Map || data['ok'] != true) return;
      final server = data['data'];

      final latestVersion = (server['latest_version'] ?? '').toString();
      final url = (server['apk_url'] ?? '').toString();
      final force = server['force_update'] == true;
      final message = (server['message'] ?? 'يوجد تحديث جديد').toString();

      final info = await PackageInfo.fromPlatform();
      if (!_isNewer(latestVersion, info.version)) return;

      final ctx = NotificationNavigationService.navigatorKey.currentState?.overlay?.context;
      if (ctx == null || !ctx.mounted) return;
      _dialogOpen = true;
      await _showUpdateDialog(ctx, message, url, force);
    } catch (_) {
    } finally {
      _busy = false;
      _dialogOpen = false;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < l.length; i++) {
      if (i >= c.length) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    String message,
    String url,
    bool force,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) => PopScope(
        canPop: !force, // التحديث الإجباري: زر الرجوع لا يغلقها
        child: AlertDialog(
          title: const Text('تحديث جديد'),
          content: Text(message),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('لاحقًا'),
              ),
            ElevatedButton(
              onPressed: () async {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
