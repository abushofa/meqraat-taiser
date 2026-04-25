import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../call/agora_call_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';
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
  Timer? _sessionTimer;
  Map<String, dynamic>? _activeSession;
  int? _lastNotifiedSessionId;

  String? _recordingUrl;
  String _recordingStatus = 'none';
  bool _recordingLoading = false;

  bool _joiningSession = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startActiveSessionPolling();
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

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/student/dashboard.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        final parsed = Map<String, dynamic>.from(body['data']);

        setState(() {
          _data = parsed;
        });

        final lastSession = parsed['last_session'];
        final sessionId = int.tryParse('${lastSession?['id'] ?? ''}');

        if (sessionId != null && sessionId > 0) {
          await _loadRecording(sessionId);
        } else {
          setState(() {
            _recordingStatus = 'none';
            _recordingUrl = null;
          });
        }
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

  Future<void> _loadRecording(int sessionId) async {
    setState(() {
      _recordingLoading = true;
    });

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/student/get_recording.php',
        queryParameters: {'session_id': sessionId},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        setState(() {
          _recordingStatus = body['status']?.toString() ?? 'none';
          _recordingUrl = body['url']?.toString();
        });
      } else {
        setState(() {
          _recordingStatus = 'none';
          _recordingUrl = null;
        });
      }
    } catch (_) {
      setState(() {
        _recordingStatus = 'none';
        _recordingUrl = null;
      });
    } finally {
      setState(() {
        _recordingLoading = false;
      });
    }
  }

  void _startActiveSessionPolling() {
    _checkActiveSession();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 10),
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

  Future<void> _downloadRecording() async {
    if (_recordingUrl == null || _recordingUrl!.isEmpty) return;

    final uri = Uri.tryParse(_recordingUrl!);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final student = _data?['student'];
    final teacher = _data?['teacher'];
    final stats = _data?['stats'];
    final lastSession = _data?['last_session'];

    final studentName = student?['name'] ?? '';
    final teacherName = teacher?['name'] ?? 'المُقرئ';

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
            _card('الاسم', studentName),
            const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  if (_recordingLoading)
                    const CircularProgressIndicator()
                  else if (_recordingStatus == 'ready' &&
                      _recordingUrl != null &&
                      _recordingUrl!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _downloadRecording,
                      icon: const Icon(Icons.download),
                      label: const Text('تحميل التسجيل'),
                    )
                  else if (_recordingStatus == 'processing')
                    const Text('⏳ التسجيل قيد التجهيز')
                  else
                    const SizedBox(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card('إجمالي الجلسات', '${stats?['total_sessions'] ?? 0}'),
            _card('الدقائق', '${stats?['total_minutes'] ?? 0}'),
          ],
        ),
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