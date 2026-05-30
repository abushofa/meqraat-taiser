import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/reply_message_sheet.dart';

class StudentMessagesScreen extends StatefulWidget {
  const StudentMessagesScreen({super.key});

  @override
  State<StudentMessagesScreen> createState() => _StudentMessagesScreenState();
}

class _StudentMessagesScreenState extends State<StudentMessagesScreen> {
  bool _loading = true;
  String? _error;
  List _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final dio = await ApiClient.getInstance();
      final response =
          await dio.get('/student/messages.php', queryParameters: {'limit': 50});
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            _messages = body['data']['messages'] as List? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() => _error =
              (body is Map ? body['message'] : null)?.toString() ??
                  'تعذر تحميل الرسائل');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCompose() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(onSent: _loadMessages),
    );
  }

  void _openReply(Map message) {
    final senderRole = message['sender_role']?.toString() ?? '';
    final senderName = message['sender_name']?.toString() ?? '—';
    final originalTitle = message['title']?.toString() ?? '';

    Future<String?> Function(String, String) onSend;

    if (senderRole == 'teacher') {
      onSend = (title, body) async {
        try {
          final dio = await ApiClient.getInstance();
          final res = await dio.post('/student/message_to_teacher.php', data: {
            'title': title,
            'body': body,
          });
          final rb = res.data;
          if (rb is Map && rb['ok'] == true) return null;
          return (rb is Map ? rb['message'] : null)?.toString() ??
              'فشل الإرسال';
        } catch (_) {
          return 'فشل الاتصال بالخادم';
        }
      };
    } else if (senderRole == 'admin') {
      onSend = (title, body) async {
        try {
          final dio = await ApiClient.getInstance();
          final res = await dio.post('/student/message_to_admin.php', data: {
            'title': title,
            'body': body,
          });
          final rb = res.data;
          if (rb is Map && rb['ok'] == true) return null;
          return (rb is Map ? rb['message'] : null)?.toString() ??
              'فشل الإرسال';
        } catch (_) {
          return 'فشل الاتصال بالخادم';
        }
      };
    } else {
      AppSnackBar.error(context, 'لا يمكن الرد على هذه الرسالة');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReplyMessageSheet(
        senderName: senderName,
        prefillTitle: originalTitle.isEmpty ? '' : 'رد: $originalTitle',
        onSend: onSend,
        onSent: _loadMessages,
      ),
    );
  }

  Widget _messageCard(Map msg) {
    final title = msg['title']?.toString() ?? 'رسالة';
    final body = msg['body']?.toString() ?? '';
    final senderName = msg['sender_name']?.toString() ?? 'غير معروف';
    final createdAt = msg['created_at']?.toString() ?? '—';
    final senderRole = msg['sender_role']?.toString() ?? '';
    final canReply = senderRole == 'teacher' || senderRole == 'admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('من: $senderName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(createdAt,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const Divider(height: 16),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
            if (canReply) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _openReply(msg),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('رد'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: _messages.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('لا توجد رسائل')),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _messageCard(_messages[i] as Map),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('رسالة جديدة'),
        backgroundColor: const Color(0xFF0F766E),
      ),
    );
  }
}

/* ===== نافذة الإرسال للمقريء ===== */

class _ComposeSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _ComposeSheet({required this.onSent});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  // to_teacher | to_admin
  String _target = 'to_teacher';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      AppSnackBar.error(context, 'نص الرسالة مطلوب');
      return;
    }

    setState(() => _sending = true);
    try {
      final dio = await ApiClient.getInstance();
      final endpoint = _target == 'to_admin'
          ? '/student/message_to_admin.php'
          : '/student/message_to_teacher.php';
      final res = await dio.post(endpoint, data: {
        'title': _titleCtrl.text.trim(),
        'body': body,
      });
      if (!mounted) return;
      final rb = res.data;
      if (rb is Map && rb['ok'] == true) {
        Navigator.pop(context);
        final label = _target == 'to_admin' ? 'المشرف' : 'المقريء';
        AppSnackBar.info(context, 'تم إرسال الرسالة للـ$label');
        widget.onSent();
      } else {
        AppSnackBar.error(context,
            (rb is Map ? rb['message'] : null)?.toString() ?? 'فشل الإرسال');
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'فشل الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('رسالة جديدة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                // Target selector
                Row(
                  children: [
                    _targetChip('to_teacher', 'للمقريء', Icons.person_outline),
                    const SizedBox(width: 10),
                    _targetChip('to_admin', 'للمشرف',
                        Icons.admin_panel_settings_outlined),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة *',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetChip(String value, String label, IconData icon) {
    final selected = _target == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16,
          color: selected ? Colors.white : const Color(0xFF0F766E)),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _target = value),
      selectedColor: const Color(0xFF0F766E),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
