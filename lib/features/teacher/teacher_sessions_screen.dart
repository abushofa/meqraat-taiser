import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/features/call/agora_call_screen.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/utils/app_labels.dart';
import '../../core/utils/time_helper.dart';

class TeacherSessionsScreen extends StatefulWidget {
  const TeacherSessionsScreen({super.key});

  @override
  State<TeacherSessionsScreen> createState() =>
      _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> {
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
        '/teacher/sessions.php',
        queryParameters: {'limit': 50},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            sessions = body['data']?['sessions'] as List? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                (body is Map ? body['message'] : null)?.toString() ??
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

  // =============================
  // 🔥 API نظيف لإنهاء الجلسة
  // =============================
  Future<bool> _callEndSessionApi(int sessionId) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/teacher/end_session.php',
        data: {'session_id': sessionId},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _continueSession(Map session) async {
    final channel = session['agora_channel']?.toString() ?? '';
    final token = session['teacher_token']?.toString() ?? '';
    final uidRaw = session['teacher_uid'];
    final appId = session['app_id']?.toString() ?? '';

    final uid = int.tryParse(uidRaw?.toString() ?? '');

    if (channel.isEmpty || token.isEmpty || uid == null || appId.isEmpty) {
      if (!mounted) return;
      AppSnackBar.error(context, 'بيانات الجلسة غير مكتملة');
      return;
    }

    final sessionId = int.tryParse(session['id'].toString());

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          appId: appId,
          token: token,
          channelName: channel,
          uid: uid,
          title: session['session_type'] == 'group'
              ? 'الجلسة الجماعية'
              : 'جلسة ${session['student_name'] ?? ''}',
          displayName: session['student_name']?.toString() ?? 'الطالب',
          isTeacher: true,
          sessionId: sessionId,

          // 🔥 أهم إصلاح هنا
          onEndSession: () async {
            if (sessionId == null) return;

            final ok = await _callEndSessionApi(sessionId);

            if (!ok && mounted) {
              AppSnackBar.error(context, 'فشل إنهاء الجلسة');
            }
          },
        ),
      ),
    );
  }

  // =============================
  // 🔥 زر إنهاء من القائمة
  // =============================
  Future<void> _endSession(Map session) async {
    final sessionId = int.tryParse(session['id'].toString());

    if (sessionId == null) {
      AppSnackBar.error(context, 'session_id غير صالح');
      return;
    }

    final ok = await _callEndSessionApi(sessionId);

    if (!mounted) return;

    if (ok) {
      AppSnackBar.success(context, 'تم إنهاء الجلسة');
      _loadSessions();
    } else {
      AppSnackBar.error(context, 'فشل إنهاء الجلسة');
    }
  }

  Widget _sessionCard(Map session) {
    final status = '${session['status'] ?? ''}';
    final type = '${session['session_type'] ?? ''}';
    final studentName = '${session['student_name'] ?? '—'}';
    final startsAt = TimeHelper.formatTime(session['starts_at']);
    final endsAt = TimeHelper.formatTime(session['ends_at']);
    final duration = '${session['duration_minutes'] ?? '—'}';
    final room = '${session['room'] ?? '—'}';

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
                    AppLabels.status(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('النوع: ${AppLabels.sessionType(type)}'),
            if (type != 'group') Text('الطالب: $studentName'),
            Text('البداية: $startsAt'),
            Text('النهاية: $endsAt'),
            Text('المدة: $duration دقيقة'),
            Text('الغرفة: $room'),
            const SizedBox(height: 10),

            if (status == 'started')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _continueSession(session),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('متابعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _endSession(session),
                      icon: const Icon(Icons.stop),
                      label: const Text('إنهاء'),
                    ),
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