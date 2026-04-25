import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/utils/admin_refresh_notifier.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _loadDashboard();

    _refreshSub = AdminRefreshNotifier.stream.listen((_) {
      if (mounted) {
        _loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  String _studentSuccessMessage(String action, dynamic body) {
    final serverMessage = body is Map
        ? body['message']?.toString().trim()
        : null;
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    if (action == 'approve') {
      return 'تم قبول الطالب بنجاح';
    }

    if (action == 'reject') {
      return 'تم رفض الطالب بنجاح';
    }

    return 'تم تحديث حالة الطالب بنجاح';
  }

  String _teacherSuccessMessage(String action, dynamic body) {
    final serverMessage = body is Map
        ? body['message']?.toString().trim()
        : null;
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }

    if (action == 'approve') {
      return 'تم قبول المُقرئ بنجاح';
    }

    if (action == 'reject') {
      return 'تم رفض المُقرئ بنجاح';
    }

    return 'تم تحديث حالة المُقرئ بنجاح';
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
      final response = await dio.get('/admin/dashboard.php');
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

  Future<void> _changeStudentStatus(int studentId, String action) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/admin/student_status.php',
        data: {'student_id': studentId, 'action': action},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        AppSnackBar.success(context, _studentSuccessMessage(action, body));

        AdminRefreshNotifier.notify();

        return;
      }

      String message = 'تعذر تحديث حالة الطالب';

      if (body is Map) {
        message = body['message']?.toString() ?? message;
      } else if (body is String && body.trim().isNotEmpty) {
        message = body;
      }

      if (!mounted) return;
      AppSnackBar.error(context, message);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'حدث خطأ غير متوقع');
    }
  }

  Future<void> _changeTeacherStatus(int teacherId, String action) async {
    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/admin/teacher_status.php',
        data: {'teacher_id': teacherId, 'action': action},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        AppSnackBar.success(context, _teacherSuccessMessage(action, body));

        AdminRefreshNotifier.notify();

        return;
      }

      String message = 'تعذر تحديث حالة المُقرئ';

      if (body is Map) {
        message = body['message']?.toString() ?? message;
      } else if (body is String && body.trim().isNotEmpty) {
        message = body;
      }

      if (!mounted) return;
      AppSnackBar.error(context, message);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'حدث خطأ غير متوقع');
    }
  }

  double _statsCardExtent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 380) return 166;
    if (width < 430) return 154;
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

  Widget _buildStudentActions(BuildContext context, Map m) {
    final targetId = int.parse((m['student_id'] ?? m['id']).toString());

    return _ResponsiveActionButtons(
      onApprove: () => _changeStudentStatus(targetId, 'approve'),
      onReject: () => _changeStudentStatus(targetId, 'reject'),
    );
  }

  Widget _buildTeacherActions(BuildContext context, Map m) {
    final targetId = int.parse((m['teacher_id'] ?? m['id']).toString());

    return _ResponsiveActionButtons(
      onApprove: () => _changeTeacherStatus(targetId, 'approve'),
      onReject: () => _changeTeacherStatus(targetId, 'reject'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة المشرف')),
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

    final stats = _data?['stats'] as Map<String, dynamic>?;
    final topTeachers = (_data?['top_teachers'] as List?) ?? [];
    final pendingStudents = (_data?['pending_students'] as List?) ?? [];
    final pendingTeachers = (_data?['pending_teachers'] as List?) ?? [];
    final unassignedStudents =
        (_data?['approved_students_unassigned'] as List?) ?? [];

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
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildStatsSection(context, stats),
            const SizedBox(height: 16),
            // 👇 باقي UI كما هو بدون تغيير
            _buildSimpleSection(
              title: 'أكثر المُقرئين نشاطًا',
              icon: Icons.local_fire_department_outlined,
              items: topTeachers,
              emptyText: 'لا توجد بيانات',
              itemBuilder: (item) {
                final m = item as Map;
                return _InfoListCard(
                  title: '${m['name'] ?? '—'}',
                  subtitle: 'عدد الجلسات: ${m['sessions'] ?? 0}',
                  icon: Icons.person_outline,
                  color: const Color(0xFFFEF3C7),
                  iconColor: Colors.orange,
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSimpleSection(
              title: 'طلبات الطلاب المعلقة',
              icon: Icons.school_outlined,
              items: pendingStudents,
              emptyText: 'لا توجد طلبات',
              itemBuilder: (item) {
                final m = item as Map;

                return _InfoListCard(
                  title: '${m['name'] ?? '—'}',
                  subtitle: _buildSubtitle([
                    'البريد: ${m['email'] ?? '—'}',
                    if (m['level'] != null)
                      'المستوى: ${AppLabels.level(m['level']?.toString())}',
                  ]),
                  icon: Icons.person_add_alt_1_outlined,
                  color: const Color(0xFFE0F2FE),
                  iconColor: Colors.lightBlue,
                  trailing: _buildOptionalStatusBadge(m['status']),
                  actionsWidget: _buildStudentActions(context, m),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSimpleSection(
              title: 'طلبات المُقرئين المعلقة',
              icon: Icons.badge_outlined,
              items: pendingTeachers,
              emptyText: 'لا توجد طلبات',
              itemBuilder: (item) {
                final m = item as Map;

                return _InfoListCard(
                  title: '${m['name'] ?? '—'}',
                  subtitle: _buildSubtitle([
                    'البريد: ${m['email'] ?? '—'}',
                    if (m['gender'] != null)
                      'الجنس: ${AppLabels.gender(m['gender']?.toString())}',
                    if (m['age'] != null) 'العمر: ${m['age']}',
                  ]),
                  icon: Icons.record_voice_over_outlined,
                  color: const Color(0xFFF3E8FF),
                  iconColor: Colors.deepPurple,
                  trailing: _buildOptionalStatusBadge(m['status']),
                  actionsWidget: _buildTeacherActions(context, m),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSimpleSection(
              title: 'طلاب معتمدون بلا مُقرئ',
              icon: Icons.link_off_outlined,
              items: unassignedStudents,
              emptyText: 'لا يوجد طلاب',
              itemBuilder: (item) {
                final m = item as Map;
                return _InfoListCard(
                  title: '${m['name'] ?? '—'}',
                  subtitle: _buildSubtitle([
                    'البريد: ${m['email'] ?? '—'}',
                    if (m['level'] != null)
                      'المستوى: ${AppLabels.level(m['level']?.toString())}',
                  ]),
                  trailing: _buildOptionalStatusBadge(m['status']),
                  icon: Icons.person_search_outlined,
                  color: const Color(0xFFDCFCE7),
                  iconColor: Colors.green,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return _DashboardCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFFCE7F3),
            child: Icon(Icons.admin_panel_settings, color: Colors.pink),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'لوحة المشرف',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'نشط',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic>? stats) {
    final items = [
      _statCard(
        'الطلاب المعتمدون',
        '${stats?['approved_students_count'] ?? 0}',
        Icons.school_outlined,
        const Color(0xFFE0F2FE),
        Colors.lightBlue,
      ),
      _statCard(
        'المُقرئون المعتمدون',
        '${stats?['approved_teachers_count'] ?? 0}',
        Icons.groups_outlined,
        const Color(0xFFF3E8FF),
        Colors.deepPurple,
      ),
      _statCard(
        'الجلسات النشطة',
        '${stats?['active_sessions_count'] ?? 0}',
        Icons.play_circle_outline,
        const Color(0xFFDCFCE7),
        Colors.green,
      ),
      _statCard(
        'جلسات اليوم',
        '${stats?['sessions_today'] ?? 0}',
        Icons.today_outlined,
        const Color(0xFFFEF3C7),
        Colors.orange,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات سريعة',
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

  Widget _buildSimpleSection({
    required String title,
    required IconData icon,
    required List items,
    required String emptyText,
    required Widget Function(dynamic item) itemBuilder,
  }) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0F766E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(emptyText),
            )
          else
            ...items.map(itemBuilder),
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
            radius: 20,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget? _buildOptionalStatusBadge(dynamic status) {
    final value = status?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return StatusBadge(status: value);
  }

  String _buildSubtitle(List<String> parts) {
    return parts.where((e) => e.trim().isNotEmpty).join('\n');
  }
}

class _InfoListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final Widget? trailing;
  final Widget? actionsWidget;

  const _InfoListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.trailing,
    this.actionsWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          if (actionsWidget != null) ...[
            const SizedBox(height: 12),
            actionsWidget!,
          ],
        ],
      ),
    );
  }
}

class _ResponsiveActionButtons extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ResponsiveActionButtons({
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 420;

        final approveButton = FilledButton(
          onPressed: onApprove,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('قبول')),
        );

        final rejectButton = OutlinedButton(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('رفض')),
        );

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [approveButton, const SizedBox(height: 8), rejectButton],
          );
        }

        return Row(
          children: [
            Expanded(child: approveButton),
            const SizedBox(width: 8),
            Expanded(child: rejectButton),
          ],
        );
      },
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