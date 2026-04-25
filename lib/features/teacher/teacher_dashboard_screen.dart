import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/ui/app_snackbar.dart';
import '../call/agora_call_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/update_checker.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  static const bool _showAgoraDebug = false;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    Future.delayed(const Duration(seconds: 2), () {
      UpdateChecker.check(context); //checkForUpdate(context);
    });
  }

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/app/version.php');

      final data = res.data['data'];

      final latest = data['latest_version'];
      final url = data['apk_url'];
      final force = data['force_update'] == true;

      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      if (_isUpdateAvailable(current, latest)) {
        _showUpdateDialog(context, url, force);
      }
    } catch (_) {
      // تجاهل أي خطأ
    }
  }

  bool _isUpdateAvailable(String current, String latest) {
    List<int> c = current.split('.').map(int.parse).toList();
    List<int> l = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length; i++) {
      if (c.length <= i) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String url, bool force) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (_) => AlertDialog(
        title: const Text('تحديث جديد متوفر'),
        content: const Text(
          'يوجد إصدار جديد من التطبيق لتحسين الأداء وإصلاح المشاكل.',
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً'),
            ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  String _sanitizeAppId(String value) {
    return value.trim();
  }

  String _sanitizeText(String value) {
    return value.trim();
  }

  Future<void> _loadDashboard() async {
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
            _data = Map<String, dynamic>.from(body['data'] as Map);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                (body is Map ? body['message'] : null)?.toString() ??
                'تعذر تحميل البيانات';
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

  Future<bool> _ensureMediaPermissions() async {
    var micStatus = await Permission.microphone.status;
    var camStatus = await Permission.camera.status;

    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (!camStatus.isGranted) {
      camStatus = await Permission.camera.request();
    }

    final granted = micStatus.isGranted && camStatus.isGranted;

    if (!granted &&
        (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied)) {
      await openAppSettings();
    }

    return granted;
  }

  Future<void> _startRecording(int sessionId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/teacher/start_recording.php',
      data: {'session_id': sessionId},
    );

    final body = response.data;

    if (body is! Map || body['ok'] != true) {
      throw Exception(
        (body is Map ? body['message'] : null)?.toString() ?? 'فشل بدء التسجيل',
      );
    }
  }

  Future<void> _stopRecording(int sessionId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/teacher/stop_recording.php',
      data: {'session_id': sessionId},
    );

    final body = response.data;

    if (body is! Map || body['ok'] != true) {
      throw Exception(
        (body is Map ? body['message'] : null)?.toString() ??
            'فشل إيقاف التسجيل',
      );
    }
  }

  Future<void> _endSessionByApi(int sessionId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/teacher/end_session.php',
      data: {'session_id': sessionId},
    );

    final body = response.data;

    if (body is! Map || body['ok'] != true) {
      throw Exception(
        (body is Map ? body['message'] : null)?.toString() ??
            'فشل إنهاء الجلسة',
      );
    }
  }

  Future<void> _openAgoraCall({
    required Map<String, dynamic> agora,
    required String title,
    required int sessionId,
    required String displayName,
  }) async {
    if (!mounted) return;

    final granted = await _ensureMediaPermissions();
    if (!granted) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'يجب السماح بالميكروفون والكاميرا لبدء الجلسة',
      );
      return;
    }

    final appId = _sanitizeAppId(agora['app_id']?.toString() ?? '');
    final channelName = _sanitizeText(agora['channel']?.toString() ?? '');
    final token = _sanitizeText(agora['teacher_token']?.toString() ?? '');

    final uidValue = agora['teacher_uid'];
    final int uid = uidValue is int
        ? uidValue
        : int.tryParse(uidValue?.toString() ?? '') ?? 0;

    if (appId.isEmpty || channelName.isEmpty || token.isEmpty || uid <= 0) {
      if (!mounted) return;
      AppSnackBar.error(context, 'بيانات Agora غير مكتملة');
      return;
    }

    if (_showAgoraDebug) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Agora Parsed Data'),
          content: SelectableText(
            'APP_ID=[$appId]\n'
            'APP_ID_LENGTH=${appId.length}\n'
            'CHANNEL=[$channelName]\n'
            'TOKEN_EMPTY=${token.isEmpty}\n'
            'UID=$uid',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    Future.microtask(() async {
      try {
        await _startRecording(sessionId);
      } catch (e) {
        debugPrint('START RECORDING ERROR: $e');
      }
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          appId: appId,
          token: token,
          channelName: channelName,
          uid: uid,
          title: title,
          displayName: displayName,
          isTeacher: true,
          onEndSession: () async {
            try {
              await _stopRecording(sessionId);
            } catch (e) {
              debugPrint('STOP RECORDING ERROR: $e');
            }

            await _endSessionByApi(sessionId);
          },
        ),
      ),
    );

    await _loadDashboard();
  }

  Future<void> _startIndividualSession(
    int studentId,
    String studentName,
    String teacherName,
  ) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/teacher/start_session.php',
        data: {'student_id': studentId, 'recording_enabled': 1},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final session = body['data']?['session'];
        final agora = session?['agora'];

        if (session != null && agora is Map && mounted) {
          await _openAgoraCall(
            agora: Map<String, dynamic>.from(agora),
            title: 'جلسة $studentName',
            sessionId: int.parse(session['id'].toString()),
            displayName: studentName,
          );
        } else {
          if (!mounted) return;
          AppSnackBar.error(context, 'لم تصل بيانات Agora من الخادم');
        }

        await _loadDashboard();
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

  Future<void> _startGroupSession(String teacherName) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/teacher/start_session.php',
        data: {'is_group': 1, 'recording_enabled': 1},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final session = body['data']?['session'];
        final agora = session?['agora'];

        if (session != null && agora is Map && mounted) {
          await _openAgoraCall(
            agora: Map<String, dynamic>.from(agora),
            title: 'الجلسة الجماعية',
            sessionId: int.parse(session['id'].toString()),
            displayName: 'مجموعة من الطلاب',
          );
        } else {
          if (!mounted) return;
          AppSnackBar.error(context, 'لم تصل بيانات Agora من الخادم');
        }

        await _loadDashboard();
      } else {
        if (!mounted) return;
        AppSnackBar.error(
          context,
          (body is Map ? body['message'] : null)?.toString() ??
              'تعذر بدء الجلسة الجماعية',
        );
      }
    } on DioException catch (e) {
      debugPrint('GROUP START DIO ERROR: ${e.response?.data}');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال'
            : 'فشل الاتصال بالخادم',
      );
    } catch (e) {
      debugPrint('GROUP START UNKNOWN ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'فشل بدء الجلسة الجماعية');
    }
  }

  double _statsCardExtent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 380) return 160;
    if (width < 430) return 150;
    return 142;
  }

  int _statsCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 380) {
      return const EdgeInsets.fromLTRB(12, 12, 12, 28);
    }
    return const EdgeInsets.fromLTRB(16, 16, 16, 32);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة المُقرئ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final teacher = _data?['teacher'] as Map<String, dynamic>?;
    final teacherName = teacher?['name']?.toString() ?? '';

    final stats = _data?['stats'] as Map<String, dynamic>?;
    final students = (_data?['students'] as List?) ?? [];
    final groupSession = _data?['group_session'] as Map<String, dynamic>?;
    final activeGroup = groupSession?['active'];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: _pagePadding(context),
          children: [
            _buildTeacherHeader(teacher),
            const SizedBox(height: 16),
            _buildGroupSessionCard(activeGroup, teacherName),
            const SizedBox(height: 16),
            _buildStatsSection(context, stats),
            const SizedBox(height: 16),
            _buildStudentsSection(students, teacherName),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherHeader(Map<String, dynamic>? teacher) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.record_voice_over, color: Colors.orange),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'بيانات المُقرئ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoTile('الاسم', value: '${teacher?['name'] ?? '—'}'),
          _infoTile('الإيميل', value: '${teacher?['email'] ?? '—'}'),
          _infoTile(
            'الحالة',
            trailing: StatusBadge(status: '${teacher?['status'] ?? ''}'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSessionCard(dynamic activeGroup, String teacherName) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.groups, color: Colors.indigo),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'الجلسة الجماعية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeGroup != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'جلسة جماعية جارية الآن',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _miniInfoRow('غرفة الجلسة', '${activeGroup['room'] ?? '—'}'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('متابعة الجلسة الجماعية'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final agora = activeGroup['agora'];
                        final sessionIdValue = activeGroup['session_id'];

                        if (agora is! Map || sessionIdValue == null) {
                          if (!mounted) return;
                          AppSnackBar.error(
                            context,
                            'بيانات Agora غير متوفرة في لوحة المُقرئ',
                          );
                          return;
                        }

                        await _openAgoraCall(
                          agora: Map<String, dynamic>.from(agora),
                          title: 'الجلسة الجماعية',
                          sessionId: int.parse(sessionIdValue.toString()),
                          displayName: teacherName,
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.groups),
                label: const Text('بدء جلسة جماعية'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _startGroupSession(teacherName),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic>? stats) {
    final items = [
      _statCard(
        'عدد الطلاب',
        '${stats?['students_count'] ?? 0}',
        Icons.people_alt_outlined,
        const Color(0xFFE0F2FE),
        Colors.lightBlue,
      ),
      _statCard(
        'جلسات نشطة',
        '${stats?['active_sessions_count'] ?? 0}',
        Icons.play_circle_outline,
        const Color(0xFFDCFCE7),
        Colors.green,
      ),
      _statCard(
        'جلسات منتهية',
        '${stats?['ended_sessions_count'] ?? 0}',
        Icons.check_circle_outline,
        const Color(0xFFF3E8FF),
        Colors.deepPurple,
      ),
      _statCard(
        'إجمالي الدقائق',
        '${stats?['total_minutes'] ?? 0}',
        Icons.timer_outlined,
        const Color(0xFFFEF3C7),
        Colors.orange,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الإحصائيات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _statsCrossAxisCount(context),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: _statsCardExtent(context),
          ),
          itemBuilder: (context, index) => items[index],
        ),
      ],
    );
  }

  Widget _buildStudentsSection(List students, String teacherName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'طلابي',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (students.isEmpty)
          _DashboardCard(
            child: const Text('لا يوجد طلاب', style: TextStyle(fontSize: 15)),
          )
        else
          ...students.map((s) => _studentCard(s as Map, teacherName)),
      ],
    );
  }

  Widget _studentCard(Map s, String teacherName) {
    final status = s['status']?.toString();
    final hasActiveSession = s['has_active_session'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE6FFFA),
                  child: Text(
                    (s['name']?.toString().isNotEmpty ?? false)
                        ? s['name'].toString()[0]
                        : 'ط',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${s['name'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (status != null && status.isNotEmpty)
                  StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 14),
            _miniInfoRow('المستوى', AppLabels.level(s['level']?.toString())),
            _miniInfoRow(
              'القراءة',
              AppLabels.qiraa(s['reading_type']?.toString()),
            ),
            _miniInfoRow('البريد', '${s['email'] ?? '—'}'),
            if (s['preferred_period'] != null)
              _miniInfoRow(
                'الفترة المفضلة',
                AppLabels.period(s['preferred_period']?.toString()),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(hasActiveSession ? Icons.login : Icons.mic),
                label: Text(hasActiveSession ? 'متابعة الجلسة' : 'بدء جلسة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  _startIndividualSession(
                    int.parse(s['student_id'].toString()),
                    (s['name'] ?? '').toString(),
                    teacherName,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, {String? value, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child:
                trailing ??
                Text(
                  value ?? '—',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}