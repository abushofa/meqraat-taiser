import 'package:flutter/material.dart';
import '../ui/app_snackbar.dart';

class ReplyMessageSheet extends StatefulWidget {
  final String senderName;
  final String prefillTitle;
  final Future<String?> Function(String title, String body) onSend;
  final VoidCallback onSent;

  const ReplyMessageSheet({
    super.key,
    required this.senderName,
    required this.prefillTitle,
    required this.onSend,
    required this.onSent,
  });

  @override
  State<ReplyMessageSheet> createState() => _ReplyMessageSheetState();
}

class _ReplyMessageSheetState extends State<ReplyMessageSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.prefillTitle);
    _bodyCtrl = TextEditingController();
  }

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
      final err = await widget.onSend(_titleCtrl.text.trim(), body);
      if (!mounted) return;
      if (err == null) {
        Navigator.pop(context);
        AppSnackBar.info(context, 'تم إرسال الرد بنجاح');
        widget.onSent();
      } else {
        AppSnackBar.error(context, err);
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.reply, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'رد على: ${widget.senderName}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الموضوع',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 5,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'نص الرد *',
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
                    label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الرد'),
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
