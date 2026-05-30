import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/utils/admin_refresh_notifier.dart';

class AdminManageStudentsScreen extends StatefulWidget {
  const AdminManageStudentsScreen({super.key});

  @override
  State<AdminManageStudentsScreen> createState() =>
      _AdminManageStudentsScreenState();
}

class _AdminManageStudentsScreenState extends State<AdminManageStudentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> waitlisted = [];
  List<Map<String, dynamic>> teachers = [];
  final Map<int, int?> _selectedTeacherByStudent = {};
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _loadData();

    _refreshSub = AdminRefreshNotifier.stream.listen((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _uniqueTeachers {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];

    for (final t in teachers) {
      final id = int.tryParse('${t['teacher_id'] ?? ''}');
      if (id != null && !seen.contains(id)) {
        seen.add(id);
        result.add(t);
      }
    }

    return result;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/admin/manage_students_data.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final loadedStudentsRaw = body['data']?['students'] as List? ?? [];
        final loadedTeachersRaw = body['data']?['teachers'] as List? ?? [];

        final loadedStudents = loadedStudentsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final loadedTeachers = loadedTeachersRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final uniqueTeachers = _buildUniqueTeachers(loadedTeachers);

        _selectedTeacherByStudent.clear();

        for (final m in loadedStudents) {
          final studentId = int.tryParse('${m['student_id'] ?? ''}');
          final teacherId = int.tryParse('${m['teacher_id'] ?? ''}');

          if (studentId != null) {
            final exists =
                teacherId != null &&
                uniqueTeachers.any(
                  (t) => int.tryParse('${t['teacher_id'] ?? ''}') == teacherId,
                );

            _selectedTeacherByStudent[studentId] = exists ? teacherId : null;
          }
        }

        final loadedWaitlistedRaw = body['data']?['waitlisted'] as List? ?? [];
        final loadedWaitlisted = loadedWaitlistedRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (!mounted) return;
        setState(() {
          students = loadedStudents;
          waitlisted = loadedWaitlisted;
          teachers = loadedTeachers;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل البيانات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال بالخادم'
            : 'فشل الاتصال بالخادم';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ غير متوقع';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildUniqueTeachers(
    List<Map<String, dynamic>> rawTeachers,
  ) {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];

    for (final t in rawTeachers) {
      final id = int.tryParse('${t['teacher_id'] ?? ''}');
      if (id != null && !seen.contains(id)) {
        seen.add(id);
        result.add(t);
      }
    }

    return result;
  }

  Future<void> _saveAssignment(int studentId) async {
    final teacherId = _selectedTeacherByStudent[studentId];

    final student = students.firstWhere(
      (e) => int.tryParse('${e['student_id'] ?? ''}') == studentId,
      orElse: () => <String, dynamic>{},
    );

    String teacherName = 'بدون مُقرئ';
    if (teacherId != null) {
      final teacher = _uniqueTeachers.firstWhere(
        (e) => int.tryParse('${e['teacher_id'] ?? ''}') == teacherId,
        orElse: () => <String, dynamic>{},
      );
      final fetchedName = teacher['name']?.toString().trim();
      if (fetchedName != null && fetchedName.isNotEmpty) {
        teacherName = fetchedName;
      }
    }

    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: 'تأكيد حفظ التعديل',
      message:
          'هل تريد تحديث ربط الطالب ${student['name'] ?? ''} إلى: $teacherName ؟',
      confirmText: 'حفظ',
      cancelText: 'إلغاء',
      icon: Icons.save_outlined,
      iconColor: Colors.teal,
    );

    if (!confirmed || !mounted) return;

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/admin/update_student_teacher.php',
        data: {'student_id': studentId, 'teacher_id': teacherId},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        AppSnackBar.success(
          context,
          body['message']?.toString() ?? 'تم حفظ التعديل',
        );
        AdminRefreshNotifier.notify();
        await _loadData();
      } else {
        if (!mounted) return;
        await AppDialogs.showInfo(
          context: context,
          title: 'تعذر الحفظ',
          message: (body is Map ? body['message'] : null)?.toString() ?? 'خطأ',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'فشل حفظ التعديل';
      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      }

      await AppDialogs.showInfo(
        context: context,
        title: 'فشل التنفيذ',
        message: message,
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context: context,
        title: 'خطأ',
        message: 'فشل حفظ التعديل',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  String _arabicCount(int n, String singular, String dual, String plural) {
    if (n == 1) return singular;
    if (n == 2) return dual;
    return '$n $plural';
  }

  String _formatRemaining(String? expectedDateStr) {
    if (expectedDateStr == null) return '—';
    final expected = DateTime.tryParse(expectedDateStr);
    if (expected == null) return '—';
    final diff = expected.difference(DateTime.now());
    if (diff.isNegative) return 'انتهت المدة';
    final days = diff.inDays;
    final months = days ~/ 30;
    final weeks = (days % 30) ~/ 7;
    final rem = (days % 30) % 7;
    final parts = <String>[];
    if (months > 0) parts.add(_arabicCount(months, 'شهر', 'شهران', 'شهور'));
    if (weeks > 0) parts.add(_arabicCount(weeks, 'أسبوع', 'أسبوعان', 'أسابيع'));
    if (rem > 0) parts.add(_arabicCount(rem, 'يوم', 'يومان', 'أيام'));
    return parts.isEmpty ? 'قريباً' : parts.join(' و ');
  }

  Future<void> _showEditWaitlistDialog(
      int studentId, String? currentExpectedDate) async {
    // احسب المدة المتبقية الحالية وحوّلها لشهور/أسابيع/أيام
    final expected = currentExpectedDate != null
        ? (DateTime.tryParse(currentExpectedDate) ?? DateTime.now())
        : DateTime.now();
    final remaining = expected.difference(DateTime.now());
    final totalRemainingDays = remaining.inDays.clamp(0, 9999);
    int months = totalRemainingDays ~/ 30;
    int weeks  = (totalRemainingDays % 30) ~/ 7;
    int days   = (totalRemainingDays % 30) % 7;

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final initMonths = months;
    final initWeeks  = weeks;
    final initDays   = days;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final totalDays = months * 30 + weeks * 7 + days;
          final newDate   = DateTime.now().add(Duration(days: totalDays));
          final isPast    = totalDays <= 0;
          final changed   = months != initMonths ||
                            weeks  != initWeeks  ||
                            days   != initDays;

          return AlertDialog(
            title: const Text('تعديل مدة الانتظار'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editDurationRow(
                  'شهور', months,
                  onDec: () => setS(() { if (months > 0) months--; }),
                  onInc: () => setS(() => months++),
                ),
                const SizedBox(height: 8),
                _editDurationRow(
                  'أسابيع', weeks,
                  onDec: () => setS(() { if (weeks > 0) weeks--; }),
                  onInc: () => setS(() => weeks++),
                ),
                const SizedBox(height: 8),
                _editDurationRow(
                  'أيام', days,
                  onDec: () => setS(() { if (days > 0) days--; }),
                  onInc: () => setS(() => days++),
                ),
                const SizedBox(height: 14),
                Text(
                  isPast
                      ? 'المدة صفر أو أقل'
                      : !changed
                          ? 'لا يوجد تعديل'
                          : 'التاريخ الجديد: ${fmtDate(newDate)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPast
                        ? Colors.red
                        : !changed
                            ? Colors.grey
                            : Colors.amber.shade800,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700),
                onPressed: (changed && !isPast)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('حفظ',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      final totalDays = months * 30 + weeks * 7 + days;
      final newDate   = DateTime.now().add(Duration(days: totalDays));
      await _doStudentAction(studentId, 'update_waitlist',
          expectedDate: fmtDate(newDate));
    }
  }

  Widget _editDurationRow(
    String label,
    int value, {
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? onDec : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.red.shade400,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onInc,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.green.shade600,
        ),
      ],
    );
  }


  Future<void> _doStudentAction(int studentId, String action,
      {String? expectedDate}) async {
    try {
      final dio = await ApiClient.getInstance();
      final data = <String, dynamic>{
        'student_id': studentId,
        'action': action,
      };
      if (action == 'update_waitlist' && expectedDate != null) {
        data['expected_date'] = expectedDate;
      }

      final response =
          await dio.post('/admin/student_status.php', data: data);
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        AppSnackBar.success(context, body['message']?.toString() ?? 'تم التحديث');
        await _loadData();
        AdminRefreshNotifier.notify();
      } else {
        if (!mounted) return;
        await AppDialogs.showInfo(
          context: context,
          title: 'تعذر التحديث',
          message: (body is Map ? body['message'] : null)?.toString() ??
              'حدث خطأ',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? e.response?.data['message']?.toString() ?? 'فشل الاتصال'
          : 'فشل الاتصال بالخادم';
      await AppDialogs.showInfo(
        context: context,
        title: 'فشل الاتصال',
        message: msg,
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context: context,
        title: 'خطأ',
        message: 'حدث خطأ غير متوقع',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Widget _waitlistedCard(Map<String, dynamic> item) {
    final studentId =
        int.tryParse('${item['student_id'] ?? ''}') ?? 0;
    final position = item['waitlist_position'];
    final expectedDate = item['expected_start_date']?.toString();
    final remaining = _formatRemaining(expectedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top,
                    color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${item['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (position != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$position',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('البريد: ${item['email'] ?? ''}',
                style: const TextStyle(fontSize: 13)),
            Text(
                'المُقرئ: ${item['teacher_name'] ?? 'غير مرتبط'}',
                style: const TextStyle(fontSize: 13)),
            if (expectedDate != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('التاريخ المتوقع للانضمام:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(expectedDate, style: const TextStyle(fontSize: 13)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المدة المتبقية:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(remaining, style: TextStyle(fontSize: 13, color: Colors.amber.shade800)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('تعديل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                    onPressed: studentId > 0
                        ? () => _showEditWaitlistDialog(studentId, item['expected_start_date']?.toString())
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('اعتماد'),
                    onPressed: studentId > 0
                        ? () => _doStudentAction(studentId, 'approve')
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('رفض'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: studentId > 0
                        ? () => _doStudentAction(studentId, 'reject')
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> item) {
    final studentId = int.tryParse('${item['student_id'] ?? ''}') ?? 0;
    final currentTeacherName = item['teacher_name']?.toString();

    final selectedTeacherId = _selectedTeacherByStudent[studentId];
    final safeValue =
        _uniqueTeachers.any(
          (t) => int.tryParse('${t['teacher_id'] ?? ''}') == selectedTeacherId,
        )
        ? selectedTeacherId
        : null;

    final dropdownItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('بدون مُقرئ')),
      ..._uniqueTeachers.map<DropdownMenuItem<int?>>((t) {
        final teacherId = int.tryParse('${t['teacher_id'] ?? ''}');
        return DropdownMenuItem<int?>(
          value: teacherId,
          child: Text('${t['name'] ?? ''}'),
        );
      }),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('المستوى: ${AppLabels.level(item['level']?.toString())}'),
            Text(
              'القراءة: ${AppLabels.qiraa(item['reading_type']?.toString())}',
            ),
            Text(
              'الفترة المفضلة: ${AppLabels.period(item['preferred_period']?.toString())}',
            ),
            Text(
              'المُقرئ الحالي: ${currentTeacherName == null || currentTeacherName.isEmpty ? 'غير مرتبط' : currentTeacherName}',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: safeValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختر المُقرئ',
                border: OutlineInputBorder(),
              ),
              items: dropdownItems,
              onChanged: (value) async {
                if (value == null) {
                  final confirm = await AppDialogs.showConfirm(
                    context: context,
                    title: 'تأكيد فك الربط',
                    message: 'هل تريد إزالة المقرئ من هذا الطالب؟',
                    confirmText: 'نعم',
                    cancelText: 'إلغاء',
                  );

                  if (!confirm) return;
                }

                setState(() {
                  _selectedTeacherByStudent[studentId] = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: studentId > 0
                    ? () => _saveAssignment(studentId)
                    : null,
                child: const Text('حفظ التعديل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'قائمة الانتظار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (waitlisted.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('لا يوجد طلاب في قائمة الانتظار'),
              )
            else
              ...waitlisted.map((e) => _waitlistedCard(e)),
            const SizedBox(height: 24),
            const Text(
              'إدارة الطلاب المعتمدين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (students.isEmpty)
              const Text('لا يوجد طلاب معتمدون')
            else
              ...students.map((e) => _studentCard(e)),
          ],
        ),
      ),
    );
  }
}
