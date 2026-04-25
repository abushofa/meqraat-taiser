import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

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
  String? _error;

  List students = [];

  String _mode = 'one_student';
  int? _selectedStudentUserId;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _loadingStudents = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/teacher/dashboard.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final loadedStudents = body['data']?['students'] as List? ?? [];

        if (mounted) {
          setState(() {
            students = loadedStudents;
            if (students.isNotEmpty) {
              _selectedStudentUserId = int.tryParse(
                students.first['user_id'].toString(),
              );
            }
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
          _loadingStudents = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نص الرسالة مطلوب')));
      return;
    }

    if (_mode == 'one_student' &&
        (_selectedStudentUserId == null || _selectedStudentUserId! <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر طالبًا')));
      return;
    }

    if (mounted) {
      setState(() {
        _sending = true;
      });
    }

    try {
      final dio = await ApiClient.getInstance();

      final Map<String, dynamic> payload = {
        'mode': _mode,
        'title': title,
        'body': body,
      };

      if (_mode == 'one_student') {
        payload['student_user_id'] = _selectedStudentUserId;
      }
      final response = await dio.post(
        '/teacher/send_message.php',
        data: payload,
      );

      final resBody = response.data;

      if (resBody is Map && resBody['ok'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة بنجاح')));

        _titleController.clear();
        _bodyController.clear();

        Navigator.pop(context, true);
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (resBody is Map ? resBody['message'] : null)?.toString() ??
                  'تعذر إرسال الرسالة',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data is Map
                ? e.response?.data['message']?.toString() ?? 'فشل الاتصال'
                : 'فشل الاتصال بالخادم',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إرسال رسالة'), centerTitle: true),
      body: _loadingStudents
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'نوع الإرسال',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  value: 'one_student',
                  groupValue: _mode,
                  title: const Text('طالب واحد'),
                  onChanged: (value) {
                    setState(() {
                      _mode = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  value: 'all_my_students',
                  groupValue: _mode,
                  title: const Text('كل طلابي'),
                  onChanged: (value) {
                    setState(() {
                      _mode = value!;
                    });
                  },
                ),

                if (_mode == 'one_student') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedStudentUserId,
                    decoration: const InputDecoration(
                      labelText: 'اختر الطالب',
                      border: OutlineInputBorder(),
                    ),
                    items: students.map<DropdownMenuItem<int>>((s) {
                      final userId = int.tryParse(s['user_id'].toString()) ?? 0;
                      final name = s['name']?.toString() ?? '';
                      return DropdownMenuItem<int>(
                        value: userId,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStudentUserId = value;
                      });
                    },
                  ),
                ],

                const SizedBox(height: 16),

                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الرسالة',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _bodyController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال'),
                  ),
                ),
              ],
            ),
    );
  }
}
