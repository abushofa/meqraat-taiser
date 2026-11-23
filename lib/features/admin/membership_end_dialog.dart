import 'package:flutter/material.dart';

/// نافذة الرفض (قبل الاعتماد) أو الحذف (بعده) لسبب مخالفة.
/// تُرجع الحقول التي تُضاف إلى الطلب: reason / send_reason / block — أو null عند الإلغاء.
/// (الاعتذار بسبب الامتلاء لا يمر من هنا: يكون بالبريد ثم "أرشفة الكل".)
class MembershipEndDialog {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required bool isDelete,
    String? name,
    bool reasonRequired = false,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      // اللمس خارج النافذة (لإخفاء لوحة المفاتيح) كان يغلقها ويضيع ما كُتب
      barrierDismissible: false,
      builder: (_) => _MembershipEndDialog(
        isDelete: isDelete,
        name: name,
        reasonRequired: reasonRequired,
      ),
    );
  }
}

class _MembershipEndDialog extends StatefulWidget {
  final bool isDelete;
  final String? name;
  final bool reasonRequired;

  const _MembershipEndDialog({
    required this.isDelete,
    required this.name,
    required this.reasonRequired,
  });

  @override
  State<_MembershipEndDialog> createState() => _MembershipEndDialogState();
}

class _MembershipEndDialogState extends State<_MembershipEndDialog> {
  final _reason = TextEditingController();
  bool _sendReason = true;
  bool _block = false;
  bool _showRequired = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final r = _reason.text.trim();
    if (widget.reasonRequired && r.isEmpty) {
      setState(() => _showRequired = true);
      return;
    }
    Navigator.pop(context, {
      'reason': r,
      'send_reason': r.isNotEmpty && _sendReason,
      'block': _block,
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasReason = _reason.text.trim().isNotEmpty;
    final who = (widget.name ?? '').trim();
    final title = widget.isDelete ? 'حذف' : 'رفض';

    return AlertDialog(
      title: Text(who.isEmpty ? title : '$title: $who'),
      content: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيصله إشعار وبريد إلكتروني بأنه ${widget.isDelete ? 'تم إنهاء عضويته (أو رفض طلبه إن لم يكن معتمدًا)' : 'تم رفض طلب تسجيله'}، '
                'مع بريد المقرأة للاستفسار، ويُنقل إلى "المحذوفون".',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _block,
                onChanged: (v) => setState(() => _block = v ?? false),
                title: const Text('منعه من التسجيل مجددًا بهذا البريد'),
                subtitle: const Text(
                  'يُرفع المنع تلقائيًا إن استرجعته',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _reason,
                minLines: 1,
                maxLines: 3,
                maxLength: 255,
                keyboardType: TextInputType.text,
                textInputAction:
                    TextInputAction.done, // زر "تم" يغلق لوحة المفاتيح
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                onChanged: (_) => setState(() => _showRequired = false),
                decoration: InputDecoration(
                  labelText: widget.reasonRequired
                      ? 'السبب'
                      : 'السبب (اختياري)',
                  hintText: 'مثال: تقديم بيانات غير صحيحة',
                  border: const OutlineInputBorder(),
                  errorText: _showRequired ? 'اكتب السبب' : null,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: hasReason && _sendReason,
                onChanged: hasReason
                    ? (v) => setState(() => _sendReason = v ?? false)
                    : null,
                title: const Text('إرسال السبب إليه'),
                subtitle: const Text(
                  'إن لم يُختر يبقى السبب في "المحذوفون" فقط',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _confirm,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(title),
        ),
      ],
    );
  }
}
