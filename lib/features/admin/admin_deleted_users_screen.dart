import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/admin_refresh_notifier.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/app_dialogs.dart';

class AdminDeletedUsersScreen extends StatefulWidget {
  const AdminDeletedUsersScreen({super.key});

  @override
  State<AdminDeletedUsersScreen> createState() =>
      _AdminDeletedUsersScreenState();
}

class _AdminDeletedUsersScreenState extends State<AdminDeletedUsersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> users = [];
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _loadDeletedUsers();

    _refreshSub = AdminRefreshNotifier.stream.listen((_) {
      if (mounted) {
        _loadDeletedUsers();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDeletedUsers() async {
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/admin/deleted_users.php');

      final body = res.data;

      if (body is Map && body['ok'] == true) {
        setState(() {
          users = (body['data']['deleted_users'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل البيانات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      } else if (e.response?.statusCode != null) {
        message = 'خطأ من الخادم: ${e.response!.statusCode}';
      }

      setState(() {
        _error = message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ غير متوقع';
        _loading = false;
      });
    }
  }

  Future<void> _restore(int userId) async {
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'استرجاع',
      message: 'هل تريد استرجاع هذا المستخدم؟',
      confirmText: 'نعم',
      cancelText: 'إلغاء',
    );

    if (!confirm) return;

    try {
      final dio = await ApiClient.getInstance();

      final res = await dio.post(
        '/admin/manage_user.php',
        data: FormData.fromMap({
          'user_id': userId.toString(),
          'action': 'restore',
        }),
      );

      final body = res.data;

      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(context, 'تم الاسترجاع');
        AdminRefreshNotifier.notify();
        _loadDeletedUsers();
      } else {
        String message = 'فشل الاسترجاع';

        if (body is Map) {
          message = body['message']?.toString() ?? message;
        } else if (body is String && body.trim().isNotEmpty) {
          message = body;
        }

        AppSnackBar.error(context, message);
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      } else if (e.response?.statusCode != null) {
        message = 'خطأ من الخادم: ${e.response!.statusCode}';
      }

      AppSnackBar.error(context, message);
    } catch (_) {
      AppSnackBar.error(context, 'خطأ غير متوقع');
    }
  }

  Future<void> _forceDelete(int userId) async {
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'حذف نهائي',
      message: '⚠️ هذا الحذف لا يمكن التراجع عنه',
      confirmText: 'حذف نهائي',
      cancelText: 'إلغاء',
    );

    if (!confirm) return;

    try {
      final dio = await ApiClient.getInstance();

      final res = await dio.post(
        '/admin/manage_user.php',
        data: FormData.fromMap({
          'user_id': userId.toString(),
          'action': 'force_delete',
        }),
      );

      final body = res.data;

      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(context, 'تم الحذف النهائي');
        _loadDeletedUsers();
      } else {
        String message = 'فشل الحذف النهائي';

        if (body is Map) {
          message = body['message']?.toString() ?? message;
        } else if (body is String && body.trim().isNotEmpty) {
          message = body;
        }

        AppSnackBar.error(context, message);
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      } else if (e.response?.statusCode != null) {
        message = 'خطأ من الخادم: ${e.response!.statusCode}';
      }

      AppSnackBar.error(context, message);
    } catch (_) {
      AppSnackBar.error(context, 'خطأ غير متوقع');
    }
  }

  Widget _card(Map m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${m['email']}'),
            Text('الدور: ${m['role']}'),
            Text('سبب الحذف: ${m['reason']}'),
            Text('تاريخ الحذف: ${m['deleted_at']}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _restore(m['user_id']),
                    child: const Text('استرجاع'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _forceDelete(m['user_id']),
                    child: const Text('حذف نهائي'),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المحذوفون')),
      body: RefreshIndicator(
        onRefresh: _loadDeletedUsers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: users.isEmpty
              ? [const Text('لا يوجد محذوفين')]
              : users.map((e) => _card(e)).toList(),
        ),
      ),
    );
  }
}
