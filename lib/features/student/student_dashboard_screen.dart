import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/day_picker_widget.dart';
import '../call/agora_call_screen.dart';

import '../../core/utils/update_checker.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _profileUser;
  Timer? _sessionTimer;
  Map<String, dynamic>? _activeSession;
  int? _lastNotifiedSessionId;

  bool _joiningSession = false;
  List<String> _scheduledDays = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startActiveSessionPolling();
    Future.delayed(const Duration(seconds: 2), () {
      UpdateChecker.check(context); //checkForUpdate(context);
    });
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = await ApiClient.getInstance();

      final results = await Future.wait([
        dio.get('/student/dashboard.php'),
        dio.get('/profile.php'),
      ]);

      final body = results[0].data;
      final profileBody = results[1].data;

      if (profileBody is Map && profileBody['ok'] == true) {
        final profileData = profileBody['data'] as Map?;
        setState(() {
          _profileUser = profileData?['user'] as Map<String, dynamic>?;
        });
      }

      if (body is Map && body['ok'] == true) {
        final parsed = Map<String, dynamic>.from(body['data']);
        final rawDays = parsed['scheduled_days'];
        setState(() {
          _data = parsed;
          if (rawDays is List) {
            _scheduledDays = rawDays.map((e) => e.toString()).toList();
          } else if (rawDays is String && rawDays.isNotEmpty) {
            _scheduledDays = rawDays.split(',');
          } else {
            _scheduledDays = [];
          }
        });

      } else {
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل البيانات';
        });
      }
    } catch (_) {
      setState(() {
        _error = 'فشل الاتصال بالخادم';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startActiveSessionPolling() {
    _checkActiveSession();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkActiveSession(),
    );
  }

  Future<void> _checkActiveSession() async {
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/student/active_session.php');
      final body = res.data;

      if (body is Map && body['ok'] == true) {
        final session = body['data']?['active_session'];

        setState(() {
          _activeSession = session is Map
              ? Map<String, dynamic>.from(session)
              : null;
        });

        final id = _activeSession?['id'];
        if (id != null && id != _lastNotifiedSessionId) {
          _lastNotifiedSessionId = id;
          if (!mounted) return;
          AppSnackBar.info(context, 'بدأت جلسة جديدة الآن');
        }
      }
    } catch (_) {}
  }

  Future<bool> _ensurePermissions() async {
    var mic = await Permission.microphone.request();
    var cam = await Permission.camera.request();

    if (!mic.isGranted || !cam.isGranted) {
      if (mic.isPermanentlyDenied || cam.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }
    return true;
  }

  Future<void> _openAgora(Map agora, String teacherName) async {
    final granted = await _ensurePermissions();
    if (!granted) return;

    final appId = '${agora['app_id'] ?? ''}'.trim();
    final channel = '${agora['channel'] ?? ''}'.trim();
    final token = '${agora['student_token'] ?? ''}'.trim();

    final uidValue = agora['student_uid'];
    final int uid = uidValue is int
        ? uidValue
        : int.tryParse('${uidValue ?? 0}') ?? 0;

    if (appId.isEmpty || channel.isEmpty || token.isEmpty || uid <= 0) {
      if (!mounted) return;
      AppSnackBar.error(context, 'بيانات الاتصال غير مكتملة');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          appId: appId,
          token: token,
          channelName: channel,
          uid: uid,
          title: 'جلسة القراءة',
          displayName: teacherName,
          isTeacher: false,
        ),
      ),
    );
  }

  Future<void> _joinCurrentSession(
    Map<String, dynamic> session,
    String teacherName,
  ) async {
    if (_joiningSession) return;

    final sessionType = '${session['session_type'] ?? 'individual'}';
    final agora = session['agora'];

    setState(() {
      _joiningSession = true;
    });

    try {
      if (sessionType == 'group') {
        final sessionId = int.tryParse('${session['id'] ?? ''}') ?? 0;
        if (sessionId <= 0) {
          throw Exception('معرّف الجلسة غير صالح');
        }

        final dio = await ApiClient.getInstance();
        final response = await dio.post(
          '/student/join_group_session.php',
          data: {'session_id': sessionId},
        );

        final body = response.data;

        if (body is! Map || body['ok'] != true) {
          throw Exception(
            (body is Map ? body['message'] : null)?.toString() ??
                'تعذر الانضمام إلى الجلسة الجماعية',
          );
        }

        final groupSession = body['data']?['session'];
        final groupAgora = groupSession?['agora'];

        if (groupAgora is! Map) {
          throw Exception('لم تصل بيانات Agora للجلسة الجماعية');
        }

        await _openAgora(Map<String, dynamic>.from(groupAgora), teacherName);
      } else {
        if (agora is! Map) {
          throw Exception('بيانات Agora غير متوفرة');
        }

        await _openAgora(Map<String, dynamic>.from(agora), teacherName);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _joiningSession = false;
        });
      }
    }
  }

  String _arabicCount(int n, String singular, String dual, String plural) {
    if (n == 1) return singular;
    if (n == 2) return dual;
    return '$n $plural';
  }

  String _formatRemaining(String? expectedDateStr) {
    if (expectedDateStr == null) return '—';
    final expected = DateTime.tryParse(expectedDateStr);
    if (expected == null) return '—';
    final diff = expected.difference(DateTime.now());
    if (diff.isNegative) return 'قريباً';
    final days = diff.inDays;
    final months = days ~/ 30;
    final weeks = (days % 30) ~/ 7;
    final rem = (days % 30) % 7;
    final parts = <String>[];
    if (months > 0) parts.add(_arabicCount(months, 'شهر', 'شهران', 'شهور'));
    if (weeks > 0) parts.add(_arabicCount(weeks, 'أسبوع', 'أسبوعان', 'أسابيع'));
    if (rem > 0) parts.add(_arabicCount(rem, 'يوم', 'يومان', 'أيام'));
    return parts.isEmpty ? 'قريباً' : parts.join(' و ');
  }

  Widget _buildWaitlistCard(Map<String, dynamic> student) {
    final position = student['waitlist_position'];
    final expectedDate = student['expected_start_date']?.toString();
    final remaining = _formatRemaining(expectedDate);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.amber.shade100,
                child: const Icon(Icons.hourglass_top, color: Colors.amber),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'قائمة الانتظار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أنت حالياً في قائمة الانتظار',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                if (position != null)
                  _waitlistRow(
                    Icons.format_list_numbered,
                    'مركزك في القائمة:',
                    '#$position',
                  ),
                if (expectedDate != null) ...[
                  const SizedBox(height: 6),
                  _waitlistRow(Icons.calendar_today, 'التاريخ المتوقع للانضمام:', expectedDate),
                  const SizedBox(height: 6),
                  _waitlistRow(Icons.timer_outlined, 'المدة المتبقية: ', remaining),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitlistRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _data?['student'] as Map<String, dynamic>?;
    final teacher = _data?['teacher'];
    final stats = _data?['stats'];
    final lastSession = _data?['last_session'];

    final teacherName = teacher?['name'] ?? 'المُقرئ';
    final studentStatus = student?['status']?.toString() ?? '';
    final isWaitlisted = studentStatus == 'waitlisted';

    final session = _activeSession ?? lastSession;
    final agora = session?['agora'];

    final hasSession =
        session != null && session['status'] == 'started' && agora != null;

    final sessionType = '${session?['session_type'] ?? ''}';
    final joinButtonText = sessionType == 'group'
        ? 'انضم إلى الجلسة الجماعية'
        : 'انضم الآن';

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة الطالب')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStudentHeader(student, _profileUser),
            const SizedBox(height: 16),
            if (isWaitlisted)
              _buildWaitlistCard(student!)
            else
              _DashboardCard(
                child: Column(
                  children: [
                    const Text(
                      'الجلسة الحالية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (hasSession)
                      ElevatedButton(
                        onPressed: _joiningSession
                            ? null
                            : () => _joinCurrentSession(
                                Map<String, dynamic>.from(session),
                                teacherName,
                              ),
                        child: _joiningSession
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(joinButtonText),
                      )
                    else
                      const Text('لا توجد جلسة'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (!isWaitlisted) ...[
              if (_scheduledDays.isNotEmpty) _buildScheduleCard(),
              _card('إجمالي الجلسات', '${stats?['total_sessions'] ?? 0}'),
              _card('الدقائق', '${stats?['total_minutes'] ?? 0}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeader(Map<String, dynamic>? student, Map<String, dynamic>? profile) {
    final name = profile?['name']?.toString().trim() ?? '—';
    final status = student?['status']?.toString() ?? '';
    return _DashboardCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(Icons.school, color: Colors.lightBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status.isNotEmpty) StatusBadge(status: status),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return _DashboardCard(
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              color: Color(0xFF0F766E), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'جدولك الأسبوعي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _scheduledDays.map((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              const Color(0xFF0F766E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        kDayLabels[day] ?? day,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String value) {
    return _DashboardCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}