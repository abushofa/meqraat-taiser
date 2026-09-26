import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/storage/session_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/notifications/notification_navigation_service.dart';
import '../../core/widgets/delete_account_dialog.dart';
import '../about/about_screen.dart';
import '../about/help_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'teacher_dashboard_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_messages_screen.dart';
import 'teacher_sessions_screen.dart';
import 'teacher_schedule_screen.dart';

class TeacherHomeShell extends StatefulWidget {
  const TeacherHomeShell({super.key});

  @override
  State<TeacherHomeShell> createState() => _TeacherHomeShellState();
}

class _TeacherHomeShellState extends State<TeacherHomeShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastPresenceAt;

  // الترتيب: الرئيسية | الطلاب | الرسائل | الجلسات | الجدول
  final List<Widget> _pages = const [
    TeacherDashboardScreen(),
    TeacherStudentsScreen(),
    TeacherMessagesScreen(),
    TeacherSessionsScreen(),
    TeacherScheduleScreen(),
  ];

  final List<String> _titles = const [
    'لوحة المُقرئ',
    'الطلاب',
    'الرسائل',
    'الجلسات',
    'الجدول الأسبوعي',
  ];

  @override
  void initState() {
    super.initState();
    NotificationNavigationService.teacherTabToOpen.addListener(_onTabRequested);
    WidgetsBinding.instance.addObserver(this);
    _reportPresence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationNavigationService.teacherTabToOpen
        .removeListener(_onTabRequested);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reportPresence();
  }

  // يسجّل دخول المقريء في وقت جلسته حتى يُبلَّغ الطالب المتأخر بوجوده — السيرفر يقرر ويمنع التكرار
  Future<void> _reportPresence() async {
    final now = DateTime.now();
    if (_lastPresenceAt != null &&
        now.difference(_lastPresenceAt!) < const Duration(minutes: 2)) {
      return;
    }
    _lastPresenceAt = now;
    try {
      final dio = await ApiClient.getInstance();
      await dio.post('/teacher/presence.php');
    } catch (_) {}
  }

  void _onTabRequested() {
    final tab = NotificationNavigationService.teacherTabToOpen.value;
    if (tab == null) return;
    const legacyMap = {0: 0, 1: 1, 2: 3, 3: 2};
    final mapped = legacyMap[tab] ?? tab;
    if (mounted) setState(() => _currentIndex = mapped.clamp(0, 4));
    NotificationNavigationService.clearTeacherTab();
  }

  Future<void> _logout() async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post(
        '/logout.php',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      // لا نحذف رمز FCM: يبقى تذكير الجلسات ودخول الطلاب ورسائلهم يصل بعد الخروج
    } catch (_) {}

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
    } else if (value == 'help') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const HelpScreen()));
    } else if (value == 'about') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AboutScreen()));
    }
  }

  Future<void> _showDeleteAccountConfirm() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (result != null && mounted) {
      _deleteAccount(reason: result.$1, comment: result.$2);
    }
  }

  Future<void> _deleteAccount({
    required String reason,
    String comment = '',
  }) async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post('/delete_account.php',
          data: {'reason': reason, 'comment': comment});
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await SessionStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: PopupMenuButton<String>(
          tooltip: 'المزيد',
          onSelected: _onMenuSelected,
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'help',
              child: Row(children: [
                Icon(Icons.help_outline),
                SizedBox(width: 10),
                Text('مساعدة'),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'about',
              child: Row(children: [
                Icon(Icons.info_outline),
                SizedBox(width: 10),
                Text('حول التطبيق'),
              ]),
            ),
            PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 10),
                Text('تسجيل الخروج'),
              ]),
            ),
          ],
          child: const Icon(Icons.more_vert),
        ),
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: PopupMenuButton<String>(
              tooltip: 'تعديل الحساب',
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                } else if (value == 'delete_account') {
                  _showDeleteAccountConfirm();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 10),
                    Text('تعديل الحساب'),
                  ]),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'delete_account',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Text('حذف الحساب',
                        style: TextStyle(color: Colors.red)),
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
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'الطلاب',
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'الجدول',
          ),
        ],
      ),
    );
  }
}
