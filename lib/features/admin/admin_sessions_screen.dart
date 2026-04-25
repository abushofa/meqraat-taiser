import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  bool _loading = true;
  String? _error;
  List sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/admin/reports.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            sessions = body['data']?['recent_sessions'] as List? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = (body is Map ? body['message'] : null)?.toString() ??
                'تعذر تحميل الجلسات';
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

  Color _statusColor(String status) {
    if (status == 'ended') return Colors.green;
    if (status == 'started') return Colors.orange;
    if (status == 'cancelled') return Colors.red;
    return Colors.grey;
  }

  String _statusText(String status) {
    switch (status) {
      case 'ended':
        return 'منتهية';
      case 'started':
        return 'نشطة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  String _typeText(String type) {
    return type == 'group' ? 'جماعية' : 'فردية';
  }

  Widget _sessionCard(Map session) {
    final status = '${session['status'] ?? ''}';
    final type = '${session['type'] ?? ''}';
    final studentName = '${session['student_name'] ?? '—'}';
    final teacherName = '${session['teacher_name'] ?? '—'}';
    final startsAt = '${session['starts_at'] ?? '—'}';
    final endsAt = '${session['ends_at'] ?? '—'}';
    final duration = '${session['duration_minutes'] ?? '—'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'جلسة #${session['id']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('النوع: ${_typeText(type)}'),
            Text('المُقرئ: $teacherName'),
            if (type != 'group') Text('الطالب: $studentName'),
            Text('البداية: $startsAt'),
            Text('النهاية: $endsAt'),
            Text('المدة: $duration دقيقة'),
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
      onRefresh: _loadSessions,
      child: sessions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('لا توجد جلسات')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                return _sessionCard(sessions[index] as Map);
              },
            ),
    );
  }
}