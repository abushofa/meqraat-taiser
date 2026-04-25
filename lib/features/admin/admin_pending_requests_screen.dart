import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';

class AdminPendingRequestsScreen extends StatefulWidget {
  const AdminPendingRequestsScreen({super.key});

  @override
  State<AdminPendingRequestsScreen> createState() =>
      _AdminPendingRequestsScreenState();
}

class _AdminPendingRequestsScreenState
    extends State<AdminPendingRequestsScreen> {
  bool _loading = true;
  String? _error;
  List students = [];
  List teachers = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/admin/pending_requests.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        setState(() {
          students = body['data']?['pending_students'] as List? ?? [];
          teachers = body['data']?['pending_teachers'] as List? ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل الطلبات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال بالخادم'
            : 'فشل الاتصال بالخادم';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ غير متوقع';
        _loading = false;
      });
    }
  }

  Future<void> _updateStudentStatus(int studentId, String action) async {
    final isApprove = action == 'approve';

    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: isApprove ? 'اعتماد الطالب' : 'رفض الطالب',
      message: isApprove
          ? 'هل تريد اعتماد هذا الطالب؟'
          : 'هل تريد رفض هذا الطالب؟',
      confirmText: isApprove ? 'اعتماد' : 'رفض',
      cancelText: 'إلغاء',
      confirmColor: isApprove ? null : Colors.red,
      icon: isApprove ? Icons.verified_outlined : Icons.block_outlined,
      iconColor: isApprove ? Colors.green : Colors.red,
    );

    if (!confirmed || !mounted) return;

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/admin/student_status.php',
        data: {'student_id': studentId, 'action': action},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        AppSnackBar.success(context, 'تم التحديث');
        await _loadPendingRequests();
        return;
      }

      String message = 'تعذر تحديث حالة الطالب';

      if (body is Map) {
        message = body['message']?.toString() ?? message;
      } else if (body is String && body.trim().isNotEmpty) {
        message = body;
      }

      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'تعذر التحديث',
        message: message,
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      } else if (e.response?.statusCode != null) {
        message = 'خطأ من الخادم: ${e.response!.statusCode}';
      }

      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'فشل الاتصال',
        message: message,
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'خطأ',
        message: 'حدث خطأ غير متوقع',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Future<void> _updateTeacherStatus(int teacherId, String action) async {
    final isApprove = action == 'approve';

    final confirmed = await AppDialogs.showConfirm(
      context: context,
      title: isApprove ? 'اعتماد المُقرئ' : 'رفض المُقرئ',
      message: isApprove
          ? 'هل تريد اعتماد هذا المُقرئ؟'
          : 'هل تريد رفض هذا المُقرئ؟',
      confirmText: isApprove ? 'اعتماد' : 'رفض',
      cancelText: 'إلغاء',
      confirmColor: isApprove ? null : Colors.red,
      icon: isApprove ? Icons.verified_outlined : Icons.block_outlined,
      iconColor: isApprove ? Colors.green : Colors.red,
    );

    if (!confirmed || !mounted) return;

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/admin/teacher_status.php',
        data: {'teacher_id': teacherId, 'action': action},
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        AppSnackBar.success(context, 'تم التحديث');
        await _loadPendingRequests();
        return;
      }

      String message = 'تعذر تحديث حالة المُقرئ';

      if (body is Map) {
        message = body['message']?.toString() ?? message;
      } else if (body is String && body.trim().isNotEmpty) {
        message = body;
      }

      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'تعذر التحديث',
        message: message,
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      } else if (e.response?.statusCode != null) {
        message = 'خطأ من الخادم: ${e.response!.statusCode}';
      }

      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'فشل الاتصال',
        message: message,
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'خطأ',
        message: 'حدث خطأ غير متوقع',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Widget _actionButtons({
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onApprove,
            child: const Text('اعتماد'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: onReject,
            child: const Text('رفض'),
          ),
        ),
      ],
    );
  }

  Widget _studentCard(Map item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('المستوى: ${AppLabels.level(item['level']?.toString())}'),
            Text(
              'القراءة: ${AppLabels.qiraa(item['reading_type']?.toString())}',
            ),
            Text(
              'الفترة المفضلة: ${AppLabels.period(item['preferred_period']?.toString())}',
            ),
            const SizedBox(height: 12),
            _actionButtons(
              onApprove: () =>
                  _updateStudentStatus(item['student_id'] as int, 'approve'),
              onReject: () =>
                  _updateStudentStatus(item['student_id'] as int, 'reject'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherCard(Map item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('القراءات: ${AppLabels.qiraatText(item['readings'])}'),
            Text(
              'فترات التوفر: ${AppLabels.periodsText(item['available_periods'])}',
            ),
            const SizedBox(height: 12),
            _actionButtons(
              onApprove: () =>
                  _updateTeacherStatus(item['teacher_id'] as int, 'approve'),
              onReject: () =>
                  _updateTeacherStatus(item['teacher_id'] as int, 'reject'),
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
      onRefresh: _loadPendingRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'طلبات الطلاب المعلقة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (students.isEmpty)
            const Text('لا توجد طلبات طلاب')
          else
            ...students.map((e) => _studentCard(e as Map)),
          const SizedBox(height: 24),
          const Text(
            'طلبات المُقرئين المعلقة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (teachers.isEmpty)
            const Text('لا توجد طلبات مُقرئين')
          else
            ...teachers.map((e) => _teacherCard(e as Map)),
        ],
      ),
    );
  }
}