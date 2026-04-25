import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';
import 'jitsi_room_screen.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  bool _loading = true;
  String? _error;
  List students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/teacher/dashboard.php');

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            students = body['data']?['students'] as List? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                (body is Map ? body['message'] : null)?.toString() ??
                'تعذر تحميل الطلاب';
          });
        }
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      if (e.response?.data is Map) {
        message = e.response?.data['message']?.toString() ?? message;
      } else if (e.message != null) {
        message = e.message!;
      }

      if (mounted) {
        setState(() {
          _error = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startIndividualSession(Map student) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/teacher/start_session.php',
        data: {'student_id': int.parse(student['student_id'].toString())},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final session = body['data']?['session'];
        final meetingUrl = session?['meeting_url']?.toString();

        if (meetingUrl != null &&
            meetingUrl.isNotEmpty &&
            session != null &&
            mounted) {
          await AppDialogs.showJitsiWarning(context);

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JitsiRoomScreen(
                roomUrl: meetingUrl,
                title: 'جلسة ${student['name'] ?? ''}',
                sessionId: int.parse(session['id'].toString()),
              ),
            ),
          );
        }
      } else {
        if (!mounted) return;
        AppSnackBar.error(
          context,
          (body is Map ? body['message'] : null)?.toString() ??
              'تعذر بدء الجلسة',
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال'
            : 'فشل الاتصال بالخادم',
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'حدث خطأ غير متوقع');
    }
  }

  Future<void> _markAttendance(Map student, String status) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/teacher/mark_attendance.php',
        data: {
          'student_id': int.parse(student['student_id'].toString()),
          'status': status,
        },
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        AppSnackBar.success(
          context,
          body['message']?.toString() ?? 'تم تسجيل الحضور بنجاح',
        );

        await _loadStudents();
      } else {
        if (!mounted) return;

        AppSnackBar.error(
          context,
          (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تسجيل الحضور',
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      AppSnackBar.error(
        context,
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال'
            : 'فشل الاتصال بالخادم',
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'حدث خطأ غير متوقع');
    }
  }

  Future<void> _showAddNoteDialog(Map student) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _AddNoteDialog(
        studentId: int.parse(student['student_id'].toString()),
        studentName: '${student['name'] ?? ''}',
      ),
    );

    if (!mounted) return;

    if (message != null && message.isNotEmpty) {
      AppSnackBar.success(context, message);
    }
  }

  Widget _attendanceButton({
    required String label,
    required String status,
    required Map student,
    required Color backgroundColor,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: backgroundColor),
        onPressed: () => _markAttendance(student, status),
        child: Text(label),
      ),
    );
  }

  Widget _studentCard(Map student) {
    final name = '${student['name'] ?? '—'}';
    final email = '${student['email'] ?? '—'}';
    final readingType = AppLabels.qiraa(student['reading_type']?.toString());
    final preferredPeriod =
        AppLabels.period(student['preferred_period']?.toString());
    final room = '${student['room'] ?? '—'}';
    final lastAttendanceStatus =
        student['last_attendance_status']?.toString() ?? '';
    final lastAttendanceDate =
        student['last_attendance_date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: $email'),
            Text("المستوى: ${AppLabels.level(student['level']?.toString())}"),
            Text('القراءة: $readingType'),
            Text('الفترة المفضلة: $preferredPeriod'),
            Text('الغرفة: $room'),
            if (lastAttendanceStatus.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'آخر حضور: ${AppLabels.status(lastAttendanceStatus)}'
                '${lastAttendanceDate.isNotEmpty ? ' - $lastAttendanceDate' : ''}',
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _startIndividualSession(student),
                  icon: const Icon(Icons.mic),
                  label: const Text('بدء جلسة'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAddNoteDialog(student),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('ملاحظة'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _attendanceButton(
                  label: 'حاضر',
                  status: 'present',
                  student: student,
                  backgroundColor: Colors.green,
                ),
                const SizedBox(width: 8),
                _attendanceButton(
                  label: 'غائب',
                  status: 'absent',
                  student: student,
                  backgroundColor: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: students.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('لا يوجد طلاب')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: students.length,
              itemBuilder: (context, index) {
                return _studentCard(students[index] as Map);
              },
            ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  final int studentId;
  final String studentName;

  const _AddNoteDialog({
    required this.studentId,
    required this.studentName,
  });

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      setState(() {
        _error = 'اكتب الملاحظة أولًا';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/teacher/add_note.php',
        data: {'student_id': widget.studentId, 'note': text},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(
          body['message']?.toString() ?? 'تم حفظ الملاحظة بنجاح',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _error =
            (body is Map ? body['message'] : null)?.toString() ??
            'تعذر حفظ الملاحظة';
        _saving = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال بالخادم'
            : 'فشل الاتصال بالخادم';
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ غير متوقع';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ملاحظة للطالب ${widget.studentName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'اكتب الملاحظة هنا',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}