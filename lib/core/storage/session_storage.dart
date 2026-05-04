import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _keyLoggedIn = 'is_logged_in';

  // 🔴 حفظ حالة تسجيل الدخول
  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, value);
  }

  // 🔴 قراءة الحالة
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  // 🔴 مسح الجلسة
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
  }
}