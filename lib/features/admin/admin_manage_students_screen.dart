import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';

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
  List<Map<String, dynamic>> teachers = [];
  final Map<int, int?> _selectedTeacherByStudent = {};

  @override
  void initState() {
    super.initState();
    _loadData();
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
            final exists = teacherId != null &&
                uniqueTeachers.any(
                  (t) => int.tryParse('${t['teacher_id'] ?? ''}') == teacherId,
                );

            _selectedTeacherByStudent[studentId] = exists ? teacherId : null;
          }
        }

        if (!mounted) return;
        setState(() {
          students = loadedStudents;
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
        data: {
          'student_id': studentId,
          'teacher_id': teacherId,
        },
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        AppSnackBar.success(
          context,
          body['message']?.toString() ?? 'تم حفظ التعديل',
        );

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

  Widget _studentCard(Map<String, dynamic> item) {
    final studentId = int.tryParse('${item['student_id'] ?? ''}') ?? 0;
    final currentTeacherName = item['teacher_name']?.toString();

    final selectedTeacherId = _selectedTeacherByStudent[studentId];
    final safeValue = _uniqueTeachers.any(
      (t) => int.tryParse('${t['teacher_id'] ?? ''}') == selectedTeacherId,
    )
        ? selectedTeacherId
        : null;

    final dropdownItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('بدون مُقرئ'),
      ),
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
            Text(
              'المستوى: ${AppLabels.level(item['level']?.toString())}',
            ),
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
              value: safeValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اختر المُقرئ',
                border: OutlineInputBorder(),
              ),
              items: dropdownItems,
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
                onPressed:
                    studentId > 0 ? () => _saveAssignment(studentId) : null,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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