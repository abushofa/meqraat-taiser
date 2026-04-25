import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
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
            _data = Map<String, dynamic>.from(body['data'] as Map);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = (body is Map ? body['message'] : null)?.toString() ??
                'تعذر تحميل التقارير';
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _simpleCard(String title, List items, String keyName, String keyValue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('لا توجد بيانات')
            else
              ...items.map((item) {
                final m = item as Map;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${m[keyName] ?? '—'} — ${m[keyValue] ?? '—'}'),
                );
              }),
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

    final attendanceStats = _data?['attendance_stats'] as Map<String, dynamic>?;
    final sessionStats = _data?['session_stats'] as Map<String, dynamic>?;
    final topAbsent = (_data?['top_absent_students'] as List?) ?? [];
    final topTeachers = (_data?['top_active_teachers'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionTitle('الحضور والغياب'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي السجلات: ${attendanceStats?['attendance_total'] ?? 0}'),
                  Text('الحضور: ${attendanceStats?['present_total'] ?? 0}'),
                  Text('الغياب: ${attendanceStats?['absent_total'] ?? 0}'),
                  Text('نسبة الغياب: ${attendanceStats?['absence_rate'] ?? 0}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('الجلسات'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي الجلسات: ${sessionStats?['sessions_total'] ?? 0}'),
                  Text('جلسات نشطة: ${sessionStats?['started_total'] ?? 0}'),
                  Text('جلسات منتهية: ${sessionStats?['ended_total'] ?? 0}'),
                  Text('متوسط المدة: ${sessionStats?['avg_duration'] ?? 0} دقيقة'),
                  Text('جلسات اليوم: ${sessionStats?['sessions_today'] ?? 0}'),
                  Text('جلسات الأسبوع: ${sessionStats?['sessions_week'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _simpleCard('أكثر الطلاب غيابًا', topAbsent, 'name', 'absences'),
          _simpleCard('أكثر المُقرئين نشاطًا', topTeachers, 'name', 'sessions'),
        ],
      ),
    );
  }
}