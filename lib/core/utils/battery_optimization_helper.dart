import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationHelper {
  static const _aggressiveOEMs = [
    'samsung', 'huawei', 'honor', 'xiaomi', 'redmi', 'poco',
    'oppo', 'realme', 'vivo', 'oneplus', 'meizu', 'asus',
    'tecno', 'infinix', 'itel',
  ];

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    final info = await DeviceInfoPlugin().androidInfo;
    final manufacturer = info.manufacturer.toLowerCase();
    final isAggressive = _aggressiveOEMs.any((oem) => manufacturer.contains(oem));
    if (!isAggressive) return;

    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getBool('battery_opt_skipped') ?? false;
    if (skipped) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('إعداد مهم', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لضمان استمرار الجلسات الصوتية عند قفل الشاشة، يجب إعفاء التطبيق من تحسين البطارية.',
                style: TextStyle(fontSize: 14, height: 1.7),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الخطوات (${info.manufacturer}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. اضغط "تفعيل" في النافذة التالية', style: TextStyle(fontSize: 13, height: 1.6)),
                    const Text('2. إذا لم تنجح، اذهب إلى:', style: TextStyle(fontSize: 13, height: 1.6)),
                    const Text('   الإعدادات ← البطارية ← التطبيقات', style: TextStyle(fontSize: 13, height: 1.6)),
                    const Text('3. ابحث عن "مقرأة التيسير"', style: TextStyle(fontSize: 13, height: 1.6)),
                    const Text('4. اختر "غير مقيّد" (Unrestricted)', style: TextStyle(fontSize: 13, height: 1.6)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('battery_opt_skipped', true);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Permission.ignoreBatteryOptimizations.request();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('تفعيل الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
