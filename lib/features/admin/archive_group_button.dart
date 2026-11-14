import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/utils/admin_refresh_notifier.dart';
import '../../core/widgets/app_dialogs.dart';

/// زر "أرشفة الكل": ينقل كل أفراد الفئة إلى المحذوفين بلقطة كاملة،
/// ويمكن استرجاعهم لاحقًا بنفس وضعهم. لا يُرسل أي إشعار لهم.
class ArchiveGroupButton extends StatefulWidget {
  /// students_waitlisted | teachers_pending
  final String group;
  final int count;

  /// مثل: "طلاب قائمة الانتظار"
  final String what;
  final VoidCallback onDone;

  const ArchiveGroupButton({
    super.key,
    required this.group,
    required this.count,
    required this.what,
    required this.onDone,
  });

  @override
  State<ArchiveGroupButton> createState() => _ArchiveGroupButtonState();
}

class _ArchiveGroupButtonState extends State<ArchiveGroupButton> {
  bool _busy = false;

  Future<void> _archive() async {
    final n = widget.count;
    final ok = await AppDialogs.showConfirm(
      context: context,
      title: 'أرشفة الكل',
      message: 'سيُنقل كل ${widget.what} ($n) إلى "المحذوفون" بكل بياناتهم.\n'
          'لن يُبلَّغوا بشيء، ويمكن استرجاع أيٍّ منهم لاحقًا بنفس وضعه.\n\nمتابعة؟',
      confirmText: 'أرشفة $n',
      cancelText: 'إلغاء',
      icon: Icons.archive_outlined,
      iconColor: Colors.blueGrey,
      confirmColor: Colors.blueGrey,
      cancelIsPrimary: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post(
        '/admin/archive.php',
        data: {
          'action': 'archive_group',
          'group': widget.group,
          'expected_count': n,
        },
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      final body = res.data;
      if (!mounted) return;
      if (body is Map && body['ok'] == true) {
        final done = (body['data']['archived'] as num?)?.toInt() ?? 0;
        final failed = (body['data']['failed'] as num?)?.toInt() ?? 0;
        failed == 0
            ? AppSnackBar.success(context, 'تمت أرشفة $done')
            : AppSnackBar.warning(context, 'أُرشف $done، وتعذّر $failed');
        AdminRefreshNotifier.notify();
        widget.onDone();
      } else {
        AppSnackBar.error(context,
            (body is Map ? body['message'] : null)?.toString() ?? 'فشلت الأرشفة');
      }
    } on DioException catch (e) {
      final d = e.response?.data;
      if (mounted) {
        AppSnackBar.error(context,
            d is Map && d['message'] != null ? d['message'].toString() : 'فشل الاتصال بالخادم');
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: _busy ? null : _archive,
      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
      icon: _busy
          ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.archive_outlined, size: 20),
      label: Text('أرشفة الكل (${widget.count})'),
    );
  }
}
