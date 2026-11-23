import 'package:flutter/material.dart';

/// نافذة الرفض (قبل الاعتماد) أو الحذف (بعده). نوعان:
/// - اعتذار لعدم توفر مكان: رسالة اعتذار (اختيارية)، يُحفظ في "المؤرشفون"، بلا سبب ولا منع.
/// - مخالفة: رفض/إنهاء عضوية، مع سبب (اختياري الإرسال) ومنع إعادة التسجيل.
/// تُرجع الحقول التي تُضاف إلى الطلب — أو null عند الإلغاء.
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
  bool _capacity = false; // false = مخالفة
  bool _notify = true; // للاعتذار: إرسال رسالة الاعتذار إليه
  bool _sendReason = false;
  bool _block = false;
  bool _showRequired = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final r = _reason.text.trim();
    if (_capacity) {
      Navigator.pop(context, {
        'end_kind': 'capacity',
        'notify': _notify,
        'reason': r, // ملاحظة داخلية اختيارية
        'send_reason': false,
        'block': false,
      });
      return;
    }
    // المخالفة: السبب مطلوب في الحذف، أو إن اختير إرساله
    if ((widget.reasonRequired || _sendReason) && r.isEmpty) {
      setState(() => _showRequired = true);
      return;
    }
    Navigator.pop(context, {
      'end_kind': 'violation',
      'notify': true,
      'reason': r,
      'send_reason': r.isNotEmpty && _sendReason,
      'block': _block,
    });
  }

  Widget _kindTile(bool capacity, String title, String subtitle) {
    final selected = _capacity == capacity;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => setState(() {
        _capacity = capacity;
        _showRequired = false;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? primary : const Color(0xFFD1D5DB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? primary : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonField({required String label}) {
    return TextField(
      controller: _reason,
      minLines: 1,
      maxLines: 3,
      maxLength: 255,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done, // زر "تم" يغلق لوحة المفاتيح
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onChanged: (_) => setState(() => _showRequired = false),
      decoration: InputDecoration(
        labelText: label,
        hintText: _capacity ? null : 'مثال: تقديم بيانات غير صحيحة',
        border: const OutlineInputBorder(),
        errorText: _showRequired ? 'اكتب السبب' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final who = (widget.name ?? '').trim();
    final title = widget.isDelete ? 'حذف' : 'رفض';

    final children = <Widget>[
      _kindTile(true, 'اعتذار لعدم توفر مكان',
          'يُحفظ في "المؤرشفون" ويمكن استرجاعه'),
      _kindTile(false, widget.isDelete ? 'إنهاء عضوية لمخالفة' : 'رفض لمخالفة',
          'يُحفظ في "المرفوضون"، مع سبب ومنع اختياريين'),
      const SizedBox(height: 4),
    ];

    if (_capacity) {
      children.addAll([
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _notify,
          onChanged: (v) => setState(() => _notify = v ?? false),
          title: const Text('إرسال رسالة الاعتذار إليه'),
          subtitle: const Text(
            'إشعار وبريد: «نعتذر عن عدم قبول طلب تسجيلك لاكتمال العدد…». '
            'ألغِ الاختيار إن كنت راسلته بنفسك.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        _reasonField(label: 'ملاحظة داخلية (اختياري)'),
      ]);
    } else {
      children.addAll([
        const Text(
          'سيصله إشعار وبريد إلكتروني بالرفض أو إنهاء العضوية، مع بريد المقرأة للاستفسار.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4B5563)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _block,
          onChanged: (v) => setState(() => _block = v ?? false),
          title: const Text('منعه من التسجيل مجددًا بهذا البريد'),
          subtitle: const Text('يُرفع المنع تلقائيًا إن استرجعته',
              style: TextStyle(fontSize: 12)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _sendReason,
          onChanged: (v) => setState(() {
            _sendReason = v ?? false;
            _showRequired = false;
          }),
          title: const Text('إرسال السبب إليه'),
          subtitle: const Text(
            'يُضاف إلى الإشعار والبريد. إن لم يُختر يبقى السبب في "المحذوفون" فقط',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        _reasonField(
          label: _sendReason
              ? 'السبب (سيُرسل إليه)'
              : widget.reasonRequired
                  ? 'السبب'
                  : 'السبب (اختياري)',
        ),
      ]);
    }

    return AlertDialog(
      title: Text(who.isEmpty ? title : '$title: $who'),
      content: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
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
