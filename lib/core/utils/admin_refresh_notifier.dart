import 'dart:async';

/// 🔔 نظام بسيط لإرسال إشعارات تحديث بين شاشات الأدمن
class AdminRefreshNotifier {
  // Stream broadcast يسمح لعدة شاشات بالاستماع
  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// 📡 الاستماع لأي تحديث
  static Stream<void> get stream => _controller.stream;

  /// 🚀 إرسال إشعار تحديث
  static void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// 🧹 (اختياري) إغلاق عند عدم الحاجة
  static void dispose() {
    _controller.close();
  }
}