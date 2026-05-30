import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/reply_message_sheet.dart';
import 'teacher_compose_message_screen.dart';

class TeacherMessagesScreen extends StatefulWidget {
  const TeacherMessagesScreen({super.key});

  @override
  State<TeacherMessagesScreen> createState() => _TeacherMessagesScreenState();
}

class _TeacherMessagesScreenState extends State<TeacherMessagesScreen>
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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final dio = await ApiClient.getInstance();
      final res =
          await dio.get('/teacher/messages.php', queryParameters: {'limit': 50});
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        if (mounted) {
          setState(() {
            _inbox = ((body['data']?['inbox'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _sent = ((body['data']?['sent'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  void _openReply(Map<String, dynamic> message) {
    final senderRole = message['sender_role']?.toString() ?? '';
    final senderId = message['sender_id'] as int?;
    final senderName = message['sender_name']?.toString() ?? '—';
    final originalTitle = message['title']?.toString() ?? '';

    Future<String?> Function(String, String) onSend;

    if (senderRole == 'admin') {
      onSend = (title, body) async {
        try {
          final dio = await ApiClient.getInstance();
          final res = await dio.post('/teacher/request_to_admin.php', data: {
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
    } else if (senderRole == 'student' &&
        senderId != null &&
        senderId > 0) {
      onSend = (title, body) async {
        try {
          final dio = await ApiClient.getInstance();
          final res =
              await dio.post('/teacher/send_message.php', data: {
            'mode': 'one_student',
            'student_user_id': senderId,
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
        onSent: _load,
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
        onPressed: () async {
          final sent = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const TeacherComposeMessageScreen()),
          );
          if (sent == true) _load();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('رسالة جديدة'),
        backgroundColor: const Color(0xFF0F766E),
      ),
    );
  }
}

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
                onReply:
                    onReply != null ? () => onReply!(messages[i]) : null,
              ),
            ),
    );
  }
}

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
        : _sentLabel();

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

  String _sentLabel() {
    final type = message['target_type']?.toString() ?? '';
    final name = message['target_name'];
    switch (type) {
      case 'student':
        return 'إلى طالب: ${name ?? '—'}';
      case 'students':
        return 'إلى جميع الطلاب';
      case 'admin':
        return 'إلى المشرف';
      default:
        return 'إلى: ${name ?? type}';
    }
  }
}
