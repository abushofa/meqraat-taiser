import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/admin_refresh_notifier.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/error_retry_view.dart';

/// تصنيف المحذوف حسب سبب الحذف
enum _Kind { all, archived, rejected, deleted }

extension on _Kind {
  String get label => switch (this) {
        _Kind.all => 'الكل',
        _Kind.archived => 'المؤرشفون',
        _Kind.rejected => 'المرفوضون',
        _Kind.deleted => 'المحذوفون',
      };
}

_Kind _kindOf(Map m) {
  final r = (m['reason'] ?? '').toString();
  if (r.startsWith('مؤرشف')) return _Kind.archived;
  if (r == 'مرفوض') return _Kind.rejected;
  return _Kind.deleted;
}

class AdminDeletedUsersScreen extends StatefulWidget {
  const AdminDeletedUsersScreen({super.key});

  @override
  State<AdminDeletedUsersScreen> createState() =>
      _AdminDeletedUsersScreenState();
}

class _AdminDeletedUsersScreenState extends State<AdminDeletedUsersScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> users = [];
  StreamSubscription? _refreshSub;

  _Kind _filter = _Kind.all;
  final Set<int> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  List<Map<String, dynamic>> get _visible => _filter == _Kind.all
      ? users
      : users.where((u) => _kindOf(u) == _filter).toList();

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

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String && data.isNotEmpty) return data;
    if (e.response?.statusCode != null) {
      return 'خطأ من الخادم: ${e.response!.statusCode}';
    }
    return 'فشل الاتصال بالخادم';
  }

  Future<void> _loadDeletedUsers() async {
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/admin/deleted_users.php');

      final body = res.data;
      if (!mounted) return;

      if (body is Map && body['ok'] == true) {
        setState(() {
          users = (body['data']['deleted_users'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _selected.removeWhere((id) => !users.any((u) => u['user_id'] == id));
          _error = null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل البيانات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _dioMessage(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
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
      message: 'هل تريد استرجاع هذا المستخدم؟\nيعود بكل بياناته وحالته السابقة.',
      confirmText: 'نعم',
      cancelText: 'إلغاء',
    );
    if (!confirm || !mounted) return;

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
      if (!mounted) return;

      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(context, 'تم الاسترجاع');
        AdminRefreshNotifier.notify();
        _loadDeletedUsers();
      } else {
        AppSnackBar.error(
            context,
            (body is Map ? body['message'] : null)?.toString() ??
                'فشل الاسترجاع');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, _dioMessage(e));
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'خطأ غير متوقع');
    }
  }

  Future<void> _restoreSelected() async {
    final n = _selected.length;
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'استرجاع المحددين',
      message:
          'سيُسترجع $n ${n == 1 ? 'مستخدم' : 'مستخدمين'} بكل بياناتهم وحالتهم السابقة.\nمتابعة؟',
      confirmText: 'استرجاع',
      cancelText: 'إلغاء',
      icon: Icons.restore,
      iconColor: Colors.teal,
    );
    if (!confirm || !mounted) return;

    setState(() => _busy = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post(
        '/admin/archive.php',
        data: {'action': 'restore_many', 'user_ids': _selected.toList()},
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      final body = res.data;
      if (!mounted) return;
      if (body is Map && body['ok'] == true) {
        final restored = (body['data']['restored'] as num?)?.toInt() ?? 0;
        final errors = (body['data']['errors'] as List?) ?? [];
        _selected.clear();
        AdminRefreshNotifier.notify();
        await _loadDeletedUsers();
        if (!mounted) return;
        if (errors.isEmpty) {
          AppSnackBar.success(context, 'تم استرجاع $restored');
        } else {
          String nameOf(int id) => users
              .firstWhere((u) => u['user_id'] == id,
                  orElse: () => {'name': '#$id'})['name']
              .toString();
          await AppDialogs.showInfo(
            context: context,
            title: 'استُرجع $restored، وتعذّر ${errors.length}',
            message: errors
                .map((e) =>
                    '• ${nameOf((e['user_id'] as num).toInt())}: ${e['message']}')
                .join('\n'),
          );
        }
      } else {
        AppSnackBar.error(
            context,
            (body is Map ? body['message'] : null)?.toString() ??
                'فشل الاسترجاع');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, _dioMessage(e));
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (!confirm || !mounted) return;

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
      if (!mounted) return;

      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(context, 'تم الحذف النهائي');
        _loadDeletedUsers();
      } else {
        AppSnackBar.error(
            context,
            (body is Map ? body['message'] : null)?.toString() ??
                'فشل الحذف النهائي');
      }
    } on DioException catch (e) {
      if (mounted) AppSnackBar.error(context, _dioMessage(e));
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'خطأ غير متوقع');
    }
  }

  void _toggle(int id) => setState(
      () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Widget _card(Map m) {
    final id = m['user_id'] as int;
    final selected = _selected.contains(id);
    final kind = _kindOf(m);
    final color = switch (kind) {
      _Kind.archived => Colors.blueGrey,
      _Kind.rejected => Colors.orange,
      _ => Colors.red,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? const BorderSide(color: Colors.teal, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _toggle(id),
        onTap: _selecting ? () => _toggle(id) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: Colors.teal,
                    onChanged: (_) => _toggle(id),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      m['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m['reason'].toString().isEmpty
                        ? 'محذوف'
                        : m['reason'].toString(),
                        style: TextStyle(fontSize: 12, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('البريد: ${m['email']}'),
              Text('الدور: ${m['role'] == 'teacher' ? 'مقرئ' : m['role'] == 'student' ? 'طالب' : m['role']}'),
              Text('تاريخ الحذف: ${m['deleted_at']}'),
              if ((m['deleted_comment'] ?? '').toString().trim().isNotEmpty)
                Text('السبب: ${m['deleted_comment']}'),
              if (m['blocked'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text('ممنوع من التسجيل مجددًا',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (!_selecting) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _restore(id),
                        child: const Text('استرجاع'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _forceDelete(id),
                        child: const Text('حذف نهائي'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
      return Scaffold(
        body: ErrorRetryView(message: _error!, onRetry: _loadDeletedUsers),
      );
    }

    final visible = _visible;
    final allVisibleSelected =
        visible.isNotEmpty && visible.every((u) => _selected.contains(u['user_id']));

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? 'محدد: ${_selected.length}' : 'المحذوفون'),
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'إلغاء التحديد',
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: [
          if (visible.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (allVisibleSelected) {
                  _selected.removeAll(visible.map((u) => u['user_id'] as int));
                } else {
                  _selected.addAll(visible.map((u) => u['user_id'] as int));
                }
              }),
              child: Text(allVisibleSelected ? 'إلغاء الكل' : 'تحديد الكل'),
            ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                for (final k in _Kind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(
                          '${k.label} (${k == _Kind.all ? users.length : users.where((u) => _kindOf(u) == k).length})'),
                      selected: _filter == k,
                      onSelected: (_) => setState(() => _filter = k),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDeletedUsers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: visible.isEmpty
                    ? [const Text('لا يوجد أحد في هذا التصنيف')]
                    : visible.map((e) => _card(e)).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _restoreSelected,
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.restore),
              label: Text('استرجاع ${_selected.length}'),
            )
          : null,
    );
  }
}
