import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'مقرأة التيسير',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'الإصدار 1.4.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          _infoCard([
            _infoRow(Icons.info_outline, 'الوصف',
                'منصة متكاملة لتعليم القرآن الكريم وتلاوته، تربط الطلاب بالمقرئين عبر جلسات صوتية مباشرة.'),
          ]),
          const SizedBox(height: 12),
          _infoCard([
            _infoRow(Icons.code_outlined, 'التطوير', 'فريق مقرأة التيسير'),
            const Divider(height: 1),
            _infoRow(Icons.language_outlined, 'الموقع', 'taiser.net'),
          ]),
          const SizedBox(height: 12),
          _infoCard([
            _infoRow(Icons.copyright_outlined, 'حقوق النشر',
                '© ${DateTime.now().year} مقرأة التيسير — جميع الحقوق محفوظة'),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
