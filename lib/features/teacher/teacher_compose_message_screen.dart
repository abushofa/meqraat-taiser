import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';

class TeacherComposeMessageScreen extends StatefulWidget {
  const TeacherComposeMessageScreen({super.key});

  @override
  State<TeacherComposeMessageScreen> createState() =>
      _TeacherComposeMessageScreenState();
}

class _TeacherComposeMessageScreenState
    extends State<TeacherComposeMessageScreen> {
  bool _loadingStudents = true;
  bool _sending = false;

  List _students = [];

  // modes: one_student | all_my_students | to_admin
  String _mode = 'one_student';
  int? _selectedStudentUserId;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/teacher/dashboard.php');
      final body = response.data;
      if (body is Map && body['ok'] == true && mounted) {
        final loaded = body['data']?['students'] as List? ?? [];
        setState(() {
          _students = loaded;
          if (_students.isNotEmpty) {
            _selectedStudentUserId =
                int.tryParse(_students.first['user_id'].toString());
          }
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      AppSnackBar.error(context, 'نص الرسالة مطلوب');
      return;
    }
    if (_mode == 'one_student' &&
        (_selectedStudentUserId == null || _selectedStudentUserId! <= 0)) {
      AppSnackBar.error(context, 'اختر طالباً');
      return;
    }

    setState(() => _sending = true);
    try {
      final dio = await ApiClient.getInstance();

      if (_mode == 'to_admin') {
        final res = await dio.post('/teacher/request_to_admin.php', data: {
          'title': title,
          'body': body,
        });
        if (!mounted) return;
        final rb = res.data;
        if (rb is Map && rb['ok'] == true) {
          AppSnackBar.info(context, 'تم إرسال الرسالة للمشرف');
          Navigator.pop(context, true);
        } else {
          AppSnackBar.error(context,
              (rb is Map ? rb['message'] : null)?.toString() ?? 'فشل الإرسال');
        }
      } else {
        final payload = <String, dynamic>{
          'mode': _mode,
          'title': title,
          'body': body,
        };
        if (_mode == 'one_student') payload['student_user_id'] = _selectedStudentUserId;

        final res = await dio.post('/teacher/send_message.php', data: payload);
        if (!mounted) return;
        final rb = res.data;
        if (rb is Map && rb['ok'] == true) {
          AppSnackBar.info(context, 'تم إرسال الرسالة بنجاح');
          Navigator.pop(context, true);
        } else {
          AppSnackBar.error(context,
              (rb is Map ? rb['message'] : null)?.toString() ?? 'فشل الإرسال');
        }
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'فشل الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إرسال رسالة'), centerTitle: true),
      body: _loadingStudents
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('نوع الإرسال',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Mode chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _modeChip('one_student', 'طالب واحد', Icons.person_outline),
                    _modeChip('all_my_students', 'كل طلابي', Icons.group_outlined),
                    _modeChip('to_admin', 'للمشرف', Icons.admin_panel_settings_outlined),
                  ],
                ),

                if (_mode == 'one_student') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedStudentUserId,
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب',
                      border: OutlineInputBorder(),
                    ),
                    items: _students.map<DropdownMenuItem<int>>((s) {
                      final userId =
                          int.tryParse(s['user_id'].toString()) ?? 0;
                      return DropdownMenuItem<int>(
                        value: userId,
                        child: Text(s['name']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedStudentUserId = v),
                  ),
                ],

                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة *',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = _mode == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16,
          color: selected ? Colors.white : const Color(0xFF0F766E)),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _mode = value;
        _selectedStudentUserId = null;
      }),
      selectedColor: const Color(0xFF0F766E),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
