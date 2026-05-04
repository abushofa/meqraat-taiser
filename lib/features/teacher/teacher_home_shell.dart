import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/storage/session_storage.dart';

import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';

import 'teacher_dashboard_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_sessions_screen.dart';
import 'teacher_messages_screen.dart';
import '../profile/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TeacherHomeShell extends StatefulWidget {
  const TeacherHomeShell({super.key});

  @override
  State<TeacherHomeShell> createState() => _TeacherHomeShellState();
}

class _TeacherHomeShellState extends State<TeacherHomeShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TeacherDashboardScreen(),
    TeacherStudentsScreen(),
    TeacherSessionsScreen(),
    TeacherMessagesScreen(),
  ];

  final List<String> _titles = const [
    'لوحة المُقرئ',
    'الطلاب',
    'الجلسات',
    'الرسائل',
  ];

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 390;
  }

  Future<void> _logout() async {
    try {
      final dio = await ApiClient.getInstance();

      await dio.post(
        '/logout.php',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      // حذف التوكن من الجهاز
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    } catch (_) {
      // لا نكسر تجربة المستخدم
    }

    // تنظيف الجلسة محليًا
    await SessionStorage.clear();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onMenuSelected(String value) {
    if (value == 'logout') {
      _logout();
    } else if (value == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = _isSmallScreen(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text('منصة تعليم القرآن', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'الحساب',
            onSelected: _onMenuSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            offset: const Offset(0, 48),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('الحساب'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('تسجيل الخروج'),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),

      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: isSmall ? 82 : 72, // 👈 الحل هنا
          labelTextStyle: WidgetStateProperty.all(
            TextStyle(
              fontSize: isSmall ? 10.5 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: isSmall ? 20 : 24),
              selectedIcon: Icon(Icons.dashboard, size: isSmall ? 20 : 24),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline, size: isSmall ? 20 : 24),
              selectedIcon: Icon(Icons.people, size: isSmall ? 20 : 24),
              label: 'الطلاب',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, size: isSmall ? 20 : 24),
              selectedIcon: Icon(Icons.history, size: isSmall ? 20 : 24),
              label: 'الجلسات',
            ),
            NavigationDestination(
              icon: Icon(Icons.mail_outline, size: isSmall ? 20 : 24),
              selectedIcon: Icon(Icons.mail, size: isSmall ? 20 : 24),
              label: 'الرسائل',
            ),
          ],
        ),
      ),
    );
  }
}
