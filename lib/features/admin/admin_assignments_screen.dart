import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';
import 'dart:async';
import '../../core/utils/admin_refresh_notifier.dart'; // ✅ جديد

class AdminAssignmentsScreen extends StatefulWidget {
  const AdminAssignmentsScreen({super.key});

  @override
  State<AdminAssignmentsScreen> createState() => _AdminAssignmentsScreenState();
}

class _AdminAssignmentsScreenState extends State<AdminAssignmentsScreen> {
  bool _loading = true;
  String? _error;
  List students = [];
  List teachers = [];
  StreamSubscription? _refreshSub;

  final Map<int, int?> _selectedTeacherByStudent = {};

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

    for (final raw in teachers) {
      if (raw is Map) {
        final t = Map<String, dynamic>.from(raw);
        final id = int.tryParse('${t['teacher_id'] ?? t['id'] ?? ''}');
        if (id != null && !seen.contains(id)) {
          seen.add(id);
          result.add(t);
        }
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _candidateTeachersForStudent(Map item) {
    final rawCandidates = item['candidate_teachers'];

    if (rawCandidates is List && rawCandidates.isNotEmpty) {
      return rawCandidates
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return _uniqueTeachers;
  }

  String _matchLabel(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? 'غير محدد' : text;
  }

  Color _matchColor(String label) {
    switch (label) {
      case 'مناسب جدًا':
        return Colors.green;
      case 'مناسب':
        return Colors.blue;
      case 'مناسب جزئيًا':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
      final response = await dio.get('/admin/assignment_data.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final loadedStudents = body['data']?['students'] as List? ?? [];
        final loadedTeachers = body['data']?['teachers'] as List? ?? [];

        if (!mounted) return;

        setState(() {
          students = loadedStudents;
          teachers = loadedTeachers;

          for (final s in students) {
            if (s is Map) {
              final studentMap = Map<String, dynamic>.from(s);
              final studentId = int.tryParse(
                '${studentMap['student_id'] ?? ''}',
              );
              if (studentId != null) {
                final candidates = _candidateTeachersForStudent(studentMap);
                final currentValue = _selectedTeacherByStudent[studentId];

                final stillExists = candidates.any(
                  (t) =>
                      int.tryParse('${t['teacher_id'] ?? t['id'] ?? ''}') ==
                      currentValue,
                );

                if (currentValue != null && !stillExists) {
                  _selectedTeacherByStudent[studentId] = null;
                }
              }
            }
          }

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

  Future<void> _assignStudent(int studentId) async {
    final teacherId = _selectedTeacherByStudent[studentId];
    if (teacherId == null || teacherId <= 0) {
      await AppDialogs.showInfo(
        context: context,
        title: 'اختيار المُقرئ',
        message: 'اختر مُقرئًا أولًا قبل تنفيذ الربط.',
        icon: Icons.person_search_outlined,
        iconColor: Colors.orange,
      );
      return;
    }

    final student = students.cast<Map?>().whereType<Map>().firstWhere(
      (e) => int.tryParse('${e['student_id'] ?? ''}') == studentId,
      orElse: () => {},
    );

    final teacherCandidates = _candidateTeachersForStudent(student);
    final teacher = teacherCandidates.firstWhere(
      (e) => int.tryParse('${e['teacher_id'] ?? e['id'] ?? ''}') == teacherId,
      orElse: () => {},
    );

    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: 'تأكيد الربط',
      message:
          'هل تريد ربط الطالب ${student['name'] ?? ''} بالمُقرئ ${teacher['name'] ?? ''}؟',
      confirmText: 'ربط',
      cancelText: 'إلغاء',
      icon: Icons.link,
      iconColor: Colors.teal,
    );

    if (!confirmed || !mounted) return;

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/admin/assign_student_teacher.php',
        data: {'student_id': studentId, 'teacher_id': teacherId},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        AppSnackBar.success(
          context,
          body['message']?.toString() ?? 'تم الربط بنجاح',
        );

        // ✅ التحديث الفوري لكل الشاشات
        AdminRefreshNotifier.notify();

        _selectedTeacherByStudent.remove(studentId);
        await _loadData();
      } else {
        if (!mounted) return;
        await AppDialogs.showInfo(
          context: context,
          title: 'تعذر تنفيذ الربط',
          message: (body is Map ? body['message'] : null)?.toString() ?? 'خطأ',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } on DioException catch (e) {
      String message = 'فشل تنفيذ الربط';

      final data = e.response?.data;
      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      }

      if (!mounted) return;
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
        message: 'فشل تنفيذ الربط',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Widget _candidateHintCard(Map<String, dynamic> candidate) {
    final label = _matchLabel(candidate['match_label']);
    final color = _matchColor(label);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${candidate['name'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('القراءات: ${AppLabels.qiraatText(candidate['readings'])}'),
          Text(
            'فترات التوفر: ${AppLabels.periodsText(candidate['available_periods'])}',
          ),
          Text('عدد الطلاب الحالي: ${candidate['students_count'] ?? 0}'),
          Text('نقاط القراءة: ${candidate['reading_score'] ?? 0}'),
          Text('نقاط الفترة: ${candidate['period_score'] ?? 0}'),
          Text('نقاط الحمل: ${candidate['load_score'] ?? 0}'),
          Text('درجة التوافق: ${candidate['score'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _studentCard(Map item) {
    final studentId = int.tryParse('${item['student_id'] ?? ''}') ?? 0;
    final candidates = _candidateTeachersForStudent(item);

    final safeValue =
        candidates.any(
          (t) =>
              int.tryParse('${t['teacher_id'] ?? t['id'] ?? ''}') ==
              _selectedTeacherByStudent[studentId],
        )
        ? _selectedTeacherByStudent[studentId]
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('المستوى: ${AppLabels.level(item['level']?.toString())}'),
            Text(
              'القراءة المطلوبة: ${AppLabels.qiraa(item['reading_type']?.toString())}',
            ),
            Text(
              'الفترة المفضلة: ${AppLabels.period(item['preferred_period']?.toString())}',
            ),
            const SizedBox(height: 14),
            if (candidates.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('لا يوجد مُقرئون مرشحون حاليًا لهذا الطالب'),
              )
            else ...[
              const Text(
                'أفضل المُقرئين المرشحين',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...candidates.take(3).map(_candidateHintCard),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: safeValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر المُقرئ',
                  border: OutlineInputBorder(),
                ),
                items: candidates.map<DropdownMenuItem<int>>((t) {
                  final teacherId =
                      int.tryParse('${t['teacher_id'] ?? t['id'] ?? ''}') ?? 0;
                  final label = _matchLabel(t['match_label']);

                  return DropdownMenuItem<int>(
                    value: teacherId,
                    child: Text(
                      '${t['name'] ?? ''} — ${AppLabels.qiraatText(t['readings'])} — $label',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
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
                      ? () => _assignStudent(studentId)
                      : null,
                  child: const Text('ربط الطالب بالمُقرئ'),
                ),
              ),
            ],
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
            const Text(
              'طلاب معتمدون بدون مُقرئ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'يعرض النظام أفضل المُقرئين المرشحين لكل طالب حسب القراءة المطلوبة والفترة المفضلة وعدد الطلاب الحالي.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (students.isEmpty)
              const Text('لا يوجد طلاب بحاجة إلى ربط')
            else
              ...students.map((e) => _studentCard(e as Map)),
          ],
        ),
      ),
    );
  }
}
