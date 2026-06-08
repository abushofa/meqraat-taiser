import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/storage/session_storage.dart';

import '../../core/notifications/notification_navigation_service.dart';
import '../../core/network/api_client.dart';
import '../about/about_screen.dart';
import '../about/help_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'student_dashboard_screen.dart';
import 'student_messages_screen.dart';
import 'student_sessions_screen.dart';
import 'student_notes_screen.dart';

class StudentHomeShell extends StatefulWidget {
  final int initialTabIndex;

  const StudentHomeShell({super.key, this.initialTabIndex = 0});

  @override
  State<StudentHomeShell> createState() => _StudentHomeShellState();
}

class _StudentHomeShellState extends State<StudentHomeShell> {
  late int _currentIndex;

  // الترتيب الجديد: الرئيسية | الرسائل | الجلسات | الملاحظات
  final List<Widget> _screens = const [
    StudentDashboardScreen(),
    StudentMessagesScreen(),
    StudentSessionsScreen(),
    StudentNotesScreen(),
  ];

  final List<String> _titles = const [
    'لوحة الطالب',
    'الرسائل',
    'الجلسات',
    'الملاحظات',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    NotificationNavigationService.studentTabToOpen
        .addListener(_onTabRequested);
  }

  @override
  void dispose() {
    NotificationNavigationService.studentTabToOpen
        .removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final tab = NotificationNavigationService.studentTabToOpen.value;
    if (tab == null) return;
    // الجلسات كانت index 1، أصبحت index 2
    // الرسائل كانت index 2، أصبحت index 1
    // الملاحظات كانت index 3، لا تزال index 3
    const legacyMap = {0: 0, 1: 2, 2: 1, 3: 3};
    final mapped = legacyMap[tab] ?? tab;
    if (mounted) setState(() => _currentIndex = mapped.clamp(0, 3));
    NotificationNavigationService.clearStudentTab();
  }

  Future<void> _logout() async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post(
        '/logout.php',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    } catch (_) {}

    await SessionStorage.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onMenuSelected(String value) {
    if (value == 'profile') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else if (value == 'logout') {
      _logout();
    } else if (value == 'help') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const HelpScreen()));
    } else if (value == 'about') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AboutScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: PopupMenuButton<String>(
              tooltip: 'القائمة',
              onSelected: _onMenuSelected,
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: const Row(children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('الملف الشخصي'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'help',
                  child: Row(children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 10),
                    Text('مساعدة'),
                  ]),
                ),
                const PopupMenuItem<String>(
                  value: 'about',
                  child: Row(children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 10),
                    Text('حول التطبيق'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 10),
                    Text('تسجيل الخروج'),
                  ]),
                ),
              ],
              child: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF0F766E),
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'الرسائل',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'الجلسات',
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
