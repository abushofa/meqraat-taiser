import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/storage/session_storage.dart';

import '../../core/notifications/notification_navigation_service.dart';
import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';

import 'student_dashboard_screen.dart';
import 'student_sessions_screen.dart';
import 'student_messages_screen.dart';
import 'student_notes_screen.dart';
import '../profile/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class StudentHomeShell extends StatefulWidget {
  final int initialTabIndex;

  const StudentHomeShell({super.key, this.initialTabIndex = 0});

  @override
  State<StudentHomeShell> createState() => _StudentHomeShellState();
}

class _StudentHomeShellState extends State<StudentHomeShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    StudentDashboardScreen(),
    StudentSessionsScreen(),
    StudentMessagesScreen(),
    StudentNotesScreen(),
  ];

  final List<String> _titles = const [
    'الرئيسية',
    'الجلسات',
    'الرسائل',
    'الملاحظات',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    NotificationNavigationService.studentTabToOpen.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    NotificationNavigationService.studentTabToOpen.removeListener(
      _onTabRequested,
    );
    super.dispose();
  }

  void _onTabRequested() {
    final tab = NotificationNavigationService.studentTabToOpen.value;
    if (tab == null) return;

    if (mounted) {
      setState(() {
        _currentIndex = tab;
      });
    }

    NotificationNavigationService.clearStudentTab();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'الحساب',
            onSelected: _onMenuSelected,
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
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'الجلسات',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'الرسائل',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_outlined),
            selectedIcon: Icon(Icons.note),
            label: 'الملاحظات',
          ),
        ],
      ),
    );
  }
}
