import 'package:flutter/material.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  static const _reasons = [
    'لم أعد بحاجة للتطبيق',
    'مشاكل تقنية',
    'أسباب تتعلق بالخصوصية',
    'أريد فتح حساب جديد',
    'أخرى',
  ];

  String? _selectedReason;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حذف الحساب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سبب الحذف:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                children: _reasons
                    .map((reason) => RadioListTile<String>(
                          value: reason,
                          title: Text(reason,
                              style: const TextStyle(fontSize: 14)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'تعليق إضافي (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 300,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () => Navigator.pop(
                    context,
                    (_selectedReason!, _commentController.text.trim()),
                  ),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}

