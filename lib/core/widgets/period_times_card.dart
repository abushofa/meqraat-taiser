import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../utils/app_labels.dart';

/// جدول مواقيت اليوم في طرابلس ووقت بدء كل فترة:
/// الأذان + الانتظار (الإقامة) + الصلاة = بدء الجلسة.
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

  bool _loading = true;
  bool _failed = false;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
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
              const Expanded(
                child: Text(
                  'مواعيد الجلسات اليوم بتوقيت طرابلس - ليبيا',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
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
        cell(p['adhan']?.toString() ?? '—', style: style),
        cell('${p['iqama'] ?? '—'}', style: style),
        cell('${p['prayer_duration'] ?? '—'}', style: style),
        cell(p['start']?.toString() ?? '—', style: style),
      ],
    );
  }
}
