import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'teacher_compose_message_screen.dart';

class TeacherMessagesScreen extends StatefulWidget {
  const TeacherMessagesScreen({super.key});

  @override
  State<TeacherMessagesScreen> createState() => _TeacherMessagesScreenState();
}

class _TeacherMessagesScreenState extends State<TeacherMessagesScreen> {
  bool _loading = true;
  String? _error;
  List messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.get(
        '/teacher/messages.php',
        queryParameters: {'limit': 50},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            messages = body['data']?['messages'] as List? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                (body is Map ? body['message'] : null)?.toString() ??
                'تعذر تحميل الرسائل';
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

  String _targetTypeText(String targetType) {
    switch (targetType) {
      case 'student':
        return 'طالب';
      case 'students':
        return 'طلاب';
      case 'teacher':
        return 'مُقرئ';
      case 'teachers':
        return 'مُقرئون';
      case 'all':
        return 'الجميع';
      default:
        return targetType;
    }
  }

  Widget _messageCard(Map message) {
    final title = '${message['title'] ?? 'رسالة'}';
    final body = '${message['body'] ?? ''}';
    final createdAt = '${message['created_at'] ?? '—'}';
    final targetType = _targetTypeText('${message['target_type'] ?? ''}');
    final targetId = message['target_id']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'نوع الإرسال: $targetType',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (targetId != null && targetId.isNotEmpty)
              Text(
                'الهدف: #$targetId',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const Divider(height: 20),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadMessages,
          child: messages.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('لا توجد رسائل')),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _messageCard(messages[index] as Map);
                  },
                ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final sent = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherComposeMessageScreen(),
                ),
              );

              if (sent == true) {
                _loadMessages();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('رسالة جديدة'),
          ),
        ),
      ],
    );
  }
}
