import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static Future<void> check(BuildContext context) async {
    try {
      final dio = Dio();
      final res = await dio.get('https://taiser.net/Quran/api/version.php');

      final data = res.data;

      if (data is! Map || data['ok'] != true) return;

      final server = data['data'];

      final latestVersion = server['latest_version'] ?? '';
      final apkUrl = server['apk_url'] ?? '';
      final forceUpdate = server['force_update'] == true;
      final message = server['message'] ?? 'يوجد تحديث جديد';

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (_isNewer(latestVersion, currentVersion)) {
        _showUpdateDialog(
          context,
          message,
          apkUrl,
          forceUpdate,
        );
      }
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length; i++) {
      if (i >= c.length) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String message,
    String url,
    bool force,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (_) => AlertDialog(
        title: const Text('تحديث جديد'),
        content: Text(message),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقًا'),
            ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }
}