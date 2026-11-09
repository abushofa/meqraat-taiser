import '../network/api_client.dart';

class AppSettingsService {
  static bool emailVerificationEnabled = false;
  static bool strongPasswordEnabled = false;
  static int maxSessionDays = 3;
  static bool schoolFullEnabled = true;
  static int schoolFullWaitMonths = 2;
  static bool teacherRegistrationEnabled = false;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/app_settings.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map? ?? {};
        emailVerificationEnabled = data['email_verification_enabled'] == true;
        strongPasswordEnabled = data['strong_password_enabled'] == true;
        maxSessionDays = (data['max_session_days'] as num?)?.toInt() ?? 3;
        schoolFullEnabled = data['school_full_enabled'] == true;
        schoolFullWaitMonths =
            (data['school_full_wait_months'] as num?)?.toInt() ?? 2;
        teacherRegistrationEnabled =
            data['teacher_registration_enabled'] == true;
        _loaded = true;
      }
    } catch (_) {}
  }

  static void reset() => _loaded = false;
}
