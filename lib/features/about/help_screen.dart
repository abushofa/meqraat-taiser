import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'كيف أسجّل في التطبيق؟',
      'a': 'اضغط على "تسجيل طالب جديد" أو "تسجيل مقريء جديد" من شاشة الدخول، أدخل بياناتك وأرسل الطلب. سيراجع المشرف طلبك ويُخبرك بالنتيجة.',
    },
    {
      'q': 'لم يصلني كود التحقق على بريدي.',
      'a': 'تحقق من مجلد Spam أو البريد غير الهام. إذا لم تجده، اضغط "لم يصلني الكود — أعد الإرسال" في شاشة التحقق.',
    },
    {
      'q': 'كيف أبدأ جلسة مع طالبي؟',
      'a': 'من لوحة المقريء، ابحث عن اسم الطالب في قائمة "طلابي" ثم اضغط "بدء جلسة".',
    },
    {
      'q': 'كيف أنضم إلى جلسة جماعية؟',
      'a': 'من لوحة الطالب، اذهب لتبويب "الجلسات" وابحث عن الجلسة الجماعية النشطة ثم اضغط "انضمام".',
    },
    {
      'q': 'كيف أرسل رسالة للمشرف أو المقريء؟',
      'a': 'اذهب لتبويب "الرسائل" ثم اضغط على زر الإنشاء (+) واختر الجهة التي تريد مراسلتها.',
    },
    {
      'q': 'كيف أحفظ تسجيل الجلسة؟',
      'a': 'اضغط زر التسجيل (●) أثناء الجلسة. عند الانتهاء يُحفظ الملف تلقائياً ويمكن الوصول إليه عبر تطبيق الملفات أو عبر الاتصال بالكمبيوتر.',
    },
    {
      'q': 'وضعني المشرف في قائمة الانتظار، ماذا يعني ذلك؟',
      'a': 'يعني أن المقريء المناسب لك مشغول حالياً. ستتلقى إشعاراً عند قبول طلبك رسمياً.',
    },
    {
      'q': 'كيف أتواصل مع الدعم؟',
      'a': 'يمكنك إرسال رسالة للمشرف من تبويب "الرسائل" داخل التطبيق.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.teal.shade50,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                faq['q']!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                Text(faq['a']!, style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ),
          );
        },
      ),
    );
  }
}
