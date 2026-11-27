import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// طلب تقييم التطبيق في المتجر بنافذة النظام الرسمية.
/// - يُطلب مرة واحدة فقط، بعد إكمال ثالث جلسة حقيقية (5 دقائق فأكثر)، وبعد الخروج منها لا أثناءها.
/// - لا نسأل "هل أعجبك؟" ولا نطلب تقييمًا إيجابيًا (ممنوع في سياسات آبل وجوجل).
/// - النظام نفسه قد لا يُظهر النافذة (حدّ مرات العرض)، فلا نعتمد على ظهورها.
class ReviewService {
  static const String appStoreId = '6812064065';
  static const _kCount = 'review_completed_sessions';
  static const _kAsked = 'review_requested';
  static const _minSessionSeconds = 300;
  static const _sessionsBeforeAsk = 3;

  /// تُستدعى بعد مغادرة الجلسة بمدتها بالثواني.
  static Future<void> afterSession(int seconds) async {
    if (seconds < _minSessionSeconds) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAsked) ?? false) return;
      final count = (prefs.getInt(_kCount) ?? 0) + 1;
      await prefs.setInt(_kCount, count);
      if (count < _sessionsBeforeAsk) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await prefs.setBool(_kAsked, true);
      // مهلة قصيرة حتى تكتمل العودة من شاشة الجلسة
      await Future.delayed(const Duration(milliseconds: 1500));
      await review.requestReview();
    } catch (e) {
      debugPrint('ReviewService: $e');
    }
  }

  /// زر «قيّم التطبيق»: يفتح صفحة التطبيق في المتجر.
  static Future<void> openStore() async {
    try {
      await InAppReview.instance.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('ReviewService.openStore: $e');
    }
  }
}
