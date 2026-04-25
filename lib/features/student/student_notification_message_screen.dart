import 'package:flutter/material.dart';

class StudentNotificationMessageScreen extends StatelessWidget {
  final String titleText;
  final String bodyText;

  const StudentNotificationMessageScreen({
    super.key,
    required this.titleText,
    required this.bodyText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الرسالة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText.isNotEmpty ? titleText : 'رسالة',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              bodyText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}