class TimeHelper {

  static DateTime? _parseUtc(String? time) {
    if (time == null || time.isEmpty) return null;

    try {
      // 🔥 نضيف Z لإجبار Flutter أنه UTC
      return DateTime.parse(time + 'Z').toLocal();
    } catch (_) {
      return null;
    }
  }

  static String formatTime(String? time) {
    final dt = _parseUtc(time);
    if (dt == null) return '—';

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');

    return "$h:$m";
  }

  static String formatDateTime(String? time) {
    final dt = _parseUtc(time);
    if (dt == null) return '—';

    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}