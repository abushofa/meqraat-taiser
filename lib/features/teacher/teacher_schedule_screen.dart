import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/day_picker_widget.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  bool _loading = true;
  String? _error;

  // قائمة الطلاب مع أيامهم
  // كل عنصر: { id, name, preferred_days: [...], scheduled_days: [...] }
  List<Map<String, dynamic>> _students = [];

  // نسخة مؤقتة من التعديلات قبل الحفظ
  // key: student_id، value: List<String> scheduled_days
  final Map<int, List<String>> _pendingChanges = {};

  bool get _hasChanges => _pendingChanges.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/teacher/schedule.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        final list = (body['data']?['students'] as List?) ?? [];
        setState(() {
          _students = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      } else {
        setState(() {
          _error = (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل الجدول';
        });
      }
    } catch (_) {
      setState(() => _error = 'فشل الاتصال بالخادم');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    if (_pendingChanges.isEmpty) return;

    setState(() => _loading = true);
    try {
      final dio = await ApiClient.getInstance();
      for (final entry in _pendingChanges.entries) {
        await dio.post('/teacher/schedule.php', data: {
          'student_id': entry.key,
          'days': entry.value.join(','),
        });
      }
      _pendingChanges.clear();
      await _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الجدول')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ، حاول مرة أخرى')),
        );
      }
      setState(() => _loading = false);
    }
  }

  List<String> _scheduledDaysFor(Map<String, dynamic> student) {
    final id = _studentId(student);
    if (_pendingChanges.containsKey(id)) return _pendingChanges[id]!;
    final raw = student['scheduled_days'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) return raw.split(',');
    return [];
  }

  List<String> _preferredDaysFor(Map<String, dynamic> student) {
    final raw = student['preferred_days'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) return raw.split(',');
    return [];
  }

  int _studentId(Map<String, dynamic> student) =>
      int.tryParse('${student['student_id'] ?? student['id'] ?? 0}') ?? 0;

  void _onDaysChanged(Map<String, dynamic> student, List<String> days) {
    final id = _studentId(student);
    setState(() => _pendingChanges[id] = days);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _loadSchedule, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadSchedule,
        child: _students.isEmpty
            ? const Center(
                child: Text(
                  'لا يوجد طلاب مرتبطون بك',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // الجدول الأسبوعي — نظرة عامة
                  _buildWeekOverview(),
                  const SizedBox(height: 20),
                  const Text(
                    'تعديل جدول كل طالب',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._students.map(_buildStudentCard),
                ],
              ),
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveAll,
              backgroundColor: const Color(0xFF0F766E),
              icon: const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text('حفظ الجدول',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  /// جدول نظرة عامة: الأيام في الأعمدة، الطلاب في الصفوف
  Widget _buildWeekOverview() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_view_week_outlined,
                    color: Color(0xFF0F766E)),
                SizedBox(width: 8),
                Text(
                  'نظرة عامة على الأسبوع',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Colors.grey.shade200, width: 1),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                // رأس الجدول
                TableRow(
                  decoration:
                      BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _headerCell('الطالب'),
                    ...kSessionDays.map(
                      (d) => _headerCell(kDayLabels[d]!),
                    ),
                  ],
                ),
                // صف لكل طالب
                ..._students.map((student) {
                  final scheduled = _scheduledDaysFor(student);
                  final preferred = _preferredDaysFor(student);
                  return TableRow(
                    children: [
                      _nameCell(
                          student['name']?.toString() ?? '—'),
                      ...kSessionDays.map((day) {
                        final isScheduled = scheduled.contains(day);
                        final isPreferred = preferred.contains(day);
                        return _dayCell(isScheduled, isPreferred);
                      }),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            // مفتاح الرموز
            Row(
              children: [
                _legendDot(const Color(0xFF0F766E)),
                const SizedBox(width: 4),
                const Text('مقرر', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                _legendDot(Colors.amber.shade600, border: true),
                const SizedBox(width: 4),
                const Text('مفضّل (غير مقرر)',
                    style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );

  Widget _nameCell(String name) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Text(
          name,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _dayCell(bool isScheduled, bool isPreferred) {
    Color? bg;
    Widget icon;
    if (isScheduled) {
      bg = const Color(0xFF0F766E).withValues(alpha: 0.12);
      icon = const Icon(Icons.check_circle,
          color: Color(0xFF0F766E), size: 18);
    } else if (isPreferred) {
      bg = Colors.amber.shade50;
      icon = Icon(Icons.star_border, color: Colors.amber.shade700, size: 18);
    } else {
      bg = null;
      icon = const SizedBox.shrink();
    }
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  Widget _legendDot(Color color, {bool border = false}) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: border ? Colors.transparent : color,
          border: border ? Border.all(color: color, width: 2) : null,
          shape: BoxShape.circle,
        ),
      );

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['name']?.toString() ?? '—';
    final preferred = _preferredDaysFor(student);
    final scheduled = _scheduledDaysFor(student);
    final id = _studentId(student);
    final hasChange = _pendingChanges.containsKey(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasChange
              ? const Color(0xFF0F766E).withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: hasChange ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE6FFFA),
                  child: Text(
                    name.isNotEmpty ? name[0] : 'ط',
                    style: const TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (hasChange)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'معدَّل',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            if (preferred.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star_border,
                      size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'مفضّل: ${preferred.map((d) => kDayLabels[d] ?? d).join('، ')}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.amber.shade800),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DayPickerWidget(
              selectedDays: scheduled,
              maxDays: 4,
              onChanged: (days) => _onDaysChanged(student, days),
            ),
          ],
        ),
      ),
    );
  }
}
