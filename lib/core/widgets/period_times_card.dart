import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../utils/app_labels.dart';

/// جدول مواقيت اليوم في طرابلس ووقت بدء كل فترة:
/// الأذان + الانتظار (الإقامة) + الصلاة = بدء الجلسة.
/// يمكن عرض الأوقات بتوقيت الجهاز إن اختلف عن توقيت طرابلس.
/// [selectedPeriod]: الفترة المختارة حالياً، تُميَّز في الجدول.
class PeriodTimesCard extends StatefulWidget {
  final String selectedPeriod;

  const PeriodTimesCard({super.key, required this.selectedPeriod});

  @override
  State<PeriodTimesCard> createState() => _PeriodTimesCardState();
}

class _PeriodTimesCardState extends State<PeriodTimesCard> {
  // تُحمَّل مرة واحدة في اليوم لكل تشغيل للتطبيق
  static Map<String, dynamic>? _cache;

  // ليبيا على GMT+2 طوال السنة (بلا توقيت صيفي)
  static const _tripoliOffset = Duration(hours: 2);
  static const _prefLocalKey = 'period_times_show_local';

  bool _loading = true;
  bool _failed = false;
  Map<String, dynamic>? _data;
  bool _showLocal = false;

  Duration get _localOffset => DateTime.now().timeZoneOffset;
  bool get _differs => _localOffset != _tripoliOffset;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTimePref();
  }

  Future<void> _loadTimePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_prefLocalKey) ?? false;
      if (mounted) setState(() => _showLocal = v);
    } catch (_) {}
  }

  Future<void> _setShowLocal(bool v) async {
    setState(() => _showLocal = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLocalKey, v);
    } catch (_) {}
  }

  static String _gmt(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final mins = offset.inMinutes.abs();
    final h = mins ~/ 60, m = mins % 60;
    return m == 0
        ? 'GMT$sign$h'
        : 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
  }

  /// يحوّل "HH:MM" من توقيت طرابلس إلى توقيت الجهاز عند اختياره،
  /// مع الإشارة إلى اليوم إن وقع الوقت في يوم آخر.
  String _time(String? tripoli) {
    if (tripoli == null || tripoli.isEmpty) return '—';
    if (!_showLocal || !_differs) return tripoli;
    final parts = tripoli.split(':');
    if (parts.length < 2) return tripoli;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return tripoli;

    final total =
        h * 60 + m + (_localOffset - _tripoliOffset).inMinutes;
    final dayShift = (total / 1440).floor();
    final mins = total - dayShift * 1440;
    final text =
        '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
    if (dayShift < 0) return '$text\n(أمس)';
    if (dayShift > 0) return '$text\n(غدًا)';
    return text;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    if (_cache != null && _cache!['date'] == _today()) {
      setState(() {
        _data = _cache;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/prayer_times.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        _cache = Map<String, dynamic>.from(body['data'] as Map);
        _data = _cache;
      } else {
        _failed = true;
      }
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_failed || _data == null) {
      content = Row(
        children: [
          const Expanded(
            child: Text(
              'تعذّر تحميل مواقيت الصلاة',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      );
    } else {
      content = _buildTable(theme);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _showLocal && _differs
                      ? 'مواعيد الجلسات اليوم بتوقيتك المحلي (${_gmt(_localOffset)})'
                      : 'مواعيد الجلسات اليوم بتوقيت طرابلس - ليبيا (GMT+2)',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_differs) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('توقيت طرابلس (GMT+2)'),
                  selected: !_showLocal,
                  onSelected: (_) => _setShowLocal(false),
                  visualDensity: VisualDensity.compact,
                ),
                ChoiceChip(
                  label: Text('توقيتك المحلي (${_gmt(_localOffset)})'),
                  selected: _showLocal,
                  onSelected: (_) => _setShowLocal(true),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildTable(ThemeData theme) {
    final periods = (_data!['periods'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    TextStyle head = const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    Widget cell(String text, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style ?? const TextStyle(fontSize: 13),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(1.4)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                cell('الفترة', style: head),
                cell('الأذان', style: head),
                cell('الانتظار', style: head),
                cell('الصلاة', style: head),
                cell('بدء الجلسة تقريبًا', style: head),
              ],
            ),
            for (final p in periods)
              _row(p, theme, cell),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'الانتظار والصلاة بالدقائق. وقت بدء الجلسة تقريبي، '
          'لأن مدة الصلاة قد تزيد أو تنقص عن ${periods.isNotEmpty ? periods.first['prayer_duration'] : 20} دقيقة. '
          'وتتغير المواعيد يومياً مع مواقيت الصلاة.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  TableRow _row(
    Map<String, dynamic> p,
    ThemeData theme,
    Widget Function(String, {TextStyle? style}) cell,
  ) {
    final selected = p['period'] == widget.selectedPeriod;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      color: selected ? theme.colorScheme.primary : null,
    );
    return TableRow(
      decoration: selected
          ? BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      children: [
        cell(AppLabels.period(p['period']?.toString()), style: style),
        cell(_time(p['adhan']?.toString()), style: style),
        cell('${p['iqama'] ?? '—'}', style: style),
        cell('${p['prayer_duration'] ?? '—'}', style: style),
        cell(_time(p['start']?.toString()), style: style),
      ],
    );
  }
}
