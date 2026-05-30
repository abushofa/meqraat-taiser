import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/reply_message_sheet.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _sent = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/admin/messages.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        setState(() {
          _inbox = ((body['data']?['inbox'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e)).toList();
          _sent = ((body['data']?['sent'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } else {
        setState(() => _error =
            (body is Map ? body['message'] : null)?.toString() ?? 'تعذر التحميل');
      }
    } catch (_) {
      setState(() => _error = 'فشل الاتصال بالخادم');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openCompose() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(onSent: _load),
    );
  }

  void _openReply(Map<String, dynamic> message) {
    final senderUserId = message['sender_user_id'] as int?;
    final senderRole = message['sender_role']?.toString() ?? '';
    final senderName = message['sender_name']?.toString() ?? '—';
    final originalTitle = message['title']?.toString() ?? '';

    if (senderUserId == null || senderUserId <= 0) {
      AppSnackBar.error(context, 'لا يمكن الرد على هذه الرسالة');
      return;
    }

    final mode = senderRole == 'teacher'
        ? 'one_teacher'
        : senderRole == 'student'
            ? 'one_student'
            : '';
    if (mode.isEmpty) {
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
        onSent: _load,
        onSend: (title, body) async {
          try {
            final dio = await ApiClient.getInstance();
            final res = await dio.post('/admin/send_message.php', data: {
              'mode': mode,
              'target_user_id': senderUserId,
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F766E),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0F766E),
              tabs: [
                Tab(text: 'الوارد (${_inbox.length})'),
                Tab(text: 'المُرسَلة (${_sent.length})'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _MessagesList(
                            messages: _inbox,
                            emptyText: 'لا توجد رسائل واردة',
                            onRefresh: _load,
                            isInbox: true,
                            onReply: _openReply,
                          ),
                          _MessagesList(
                            messages: _sent,
                            emptyText: 'لا توجد رسائل مُرسَلة',
                            onRefresh: _load,
                            isInbox: false,
                          ),
                        ],
                      ),
          ),
        ],
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

/* ===== قائمة الرسائل ===== */

class _MessagesList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String emptyText;
  final Future<void> Function() onRefresh;
  final bool isInbox;
  final void Function(Map<String, dynamic>)? onReply;

  const _MessagesList({
    required this.messages,
    required this.emptyText,
    required this.onRefresh,
    required this.isInbox,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: messages.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(emptyText,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: messages.length,
              itemBuilder: (_, i) => _MessageCard(
                message: messages[i],
                isInbox: isInbox,
                onReply: onReply != null ? () => onReply!(messages[i]) : null,
              ),
            ),
    );
  }
}

/* ===== بطاقة الرسالة ===== */

class _MessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isInbox;
  final VoidCallback? onReply;

  const _MessageCard({
    required this.message,
    required this.isInbox,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final title = message['title']?.toString() ?? '—';
    final body = message['body']?.toString() ?? '';
    final date = message['created_at']?.toString() ?? '';
    final subtitle = isInbox
        ? 'من: ${message['sender_name'] ?? '—'}'
        : _targetLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(date,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const Divider(height: 16),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
            if (onReply != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onReply,
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

  String _targetLabel() {
    final type = message['target_type']?.toString() ?? '';
    final name = message['target_name'];
    switch (type) {
      case 'student':
        return 'إلى طالب: ${name ?? '—'}';
      case 'teacher':
        return 'إلى مقريء: ${name ?? '—'}';
      case 'students':
        return 'إلى جميع الطلاب';
      case 'teachers':
        return 'إلى جميع المقرئين';
      case 'all':
        return 'إلى الجميع';
      default:
        return AppLabels.targetType(type);
    }
  }
}

/* ===== نافذة الإرسال ===== */

class _ComposeSheet extends StatefulWidget {
  final VoidCallback onSent;
  const _ComposeSheet({required this.onSent});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  String _mode = 'one_student';
  int? _targetUserId;

  bool _loadingTargets = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _sending = false;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  static const _modes = [
    ('one_student', 'طالب واحد'),
    ('one_teacher', 'مقريء واحد'),
    ('all_students', 'جميع الطلاب'),
    ('all_teachers', 'جميع المقرئين'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    setState(() => _loadingTargets = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/admin/manage_students_data.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        setState(() {
          _students = ((body['data']?['students'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e)).toList();
          _teachers = ((body['data']?['teachers'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
    finally {
      setState(() => _loadingTargets = false);
    }
  }

  Future<void> _send() async {
    final bodyText = _bodyCtrl.text.trim();
    if (bodyText.isEmpty) {
      AppSnackBar.error(context, 'نص الرسالة مطلوب');
      return;
    }
    if ((_mode == 'one_student' || _mode == 'one_teacher') &&
        _targetUserId == null) {
      AppSnackBar.error(context, 'اختر المستقبِل');
      return;
    }

    setState(() => _sending = true);
    try {
      final dio = await ApiClient.getInstance();
      final data = <String, dynamic>{
        'mode': _mode,
        'title': _titleCtrl.text.trim(),
        'body': bodyText,
      };
      if (_targetUserId != null) data['target_user_id'] = _targetUserId;

      final res = await dio.post('/admin/send_message.php', data: data);
      final resBody = res.data;
      if (!mounted) return;
      if (resBody is Map && resBody['ok'] == true) {
        Navigator.pop(context);
        AppSnackBar.info(context, 'تم الإرسال بنجاح');
        widget.onSent();
      } else {
        AppSnackBar.error(context,
            (resBody is Map ? resBody['message'] : null)?.toString() ??
                'فشل الإرسال');
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'فشل الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _needsTarget =>
      _mode == 'one_student' || _mode == 'one_teacher';

  List<Map<String, dynamic>> get _currentList =>
      _mode == 'one_student' ? _students : _teachers;

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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('رسالة جديدة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _modes.map(((String, String) m) {
                    final selected = _mode == m.$1;
                    return ChoiceChip(
                      label: Text(m.$2),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _mode = m.$1;
                        _targetUserId = null;
                      }),
                      selectedColor: const Color(0xFF0F766E),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                if (_needsTarget) ...[
                  _loadingTargets
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          initialValue: _targetUserId,
                          decoration: InputDecoration(
                            labelText: _mode == 'one_student'
                                ? 'اختر الطالب'
                                : 'اختر المقريء',
                            border: const OutlineInputBorder(),
                          ),
                          items: _currentList.map((item) {
                            final userId = int.tryParse(
                                    '${item['user_id'] ?? ''}') ??
                                0;
                            return DropdownMenuItem<int>(
                              value: userId,
                              child: Text(item['name']?.toString() ?? ''),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _targetUserId = v),
                        ),
                  const SizedBox(height: 12),
                ],
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
                            width: 18, height: 18,
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
}
