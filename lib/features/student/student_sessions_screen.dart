import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class StudentSessionsScreen extends StatefulWidget {
  const StudentSessionsScreen({super.key});

  @override
  State<StudentSessionsScreen> createState() => _StudentSessionsScreenState();
}

class _StudentSessionsScreenState extends State<StudentSessionsScreen> {
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

      final response = await dio.get(
        '/student/sessions.php',
        queryParameters: {"limit": 50},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            sessions = body['data']['sessions'] as List? ?? [];
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
      if (mounted) {
        setState(() {
          _error = e.response?.data is Map
              ? e.response?.data['message']?.toString()
              : 'فشل الاتصال بالخادم';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'خطأ غير متوقع';
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
                Center(child: Text("لا توجد جلسات")),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final s = sessions[index] as Map;

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
                              "جلسة #${s['id']}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor('${s['status']}'),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusText('${s['status']}'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("النوع: ${_typeText('${s['session_type']}')}"),
                        Text("البداية: ${s['starts_at'] ?? '-'}"),
                        Text("النهاية: ${s['ends_at'] ?? '-'}"),
                        Text(
                          "المدة: ${s['duration_minutes'] ?? '-'} دقيقة",
                        ),
                        const SizedBox(height: 8),
                        if (s['meeting_url'] != null &&
                            '${s['meeting_url']}'.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.video_call),
                            label: const Text("دخول الجلسة"),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}