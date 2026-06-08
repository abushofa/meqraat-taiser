import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/notifications/notification_navigation_service.dart';
import '../../core/ui/app_snackbar.dart';
import '../auth/login_screen.dart';
import '../about/about_screen.dart';
import '../about/help_screen.dart';
import '../profile/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/storage/session_storage.dart';

import 'admin_dashboard_screen.dart';
import 'admin_messages_screen.dart';
import 'admin_accounts_tab_screen.dart';
import 'admin_monitoring_tab_screen.dart';

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _accountsKey = GlobalKey<AdminAccountsTabScreenState>();

  // حالة درور الإعدادات
  bool _evEnabled = false;
  bool _spEnabled = false;
  bool _evOriginal = false;
  bool _spOriginal = false;
  int _maxSessionDays = 3;
  int _maxSessionDaysOriginal = 3;
  bool _drawerLoading = false;
  bool _drawerSaving = false;

  bool get _settingsChanged =>
      _evEnabled != _evOriginal ||
      _spEnabled != _spOriginal ||
      _maxSessionDays != _maxSessionDaysOriginal;

  late final List<Widget> _pages = [
    const AdminDashboardScreen(),
    AdminAccountsTabScreen(key: _accountsKey),
    const AdminMonitoringTabScreen(),
    const AdminMessagesScreen(),
  ];

  final List<String> _titles = const [
    'لوحة المشرف',
    'الحسابات',
    'المتابعة',
    'التواصل',
  ];

  @override
  void initState() {
    super.initState();
    NotificationNavigationService.adminTabToOpen.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    NotificationNavigationService.adminTabToOpen
        .removeListener(_onTabRequested);
    super.dispose();
  }

  // مخطط التحويل: الفهرس القديم (0-8) → (tabIndex, subIndex)
  // 0:dashboard→(0,-), 1:requests→(1,0), 2:assignments→(1,1),
  // 3:manage→(1,2), 4:messages→(3,-), 5:sessions→(2,0),
  // 6:reports→(2,1), 7:directory→(1,3), 8:deleted→(1,4)
  void _onTabRequested() {
    final tab = NotificationNavigationService.adminTabToOpen.value;
    if (tab == null) return;

    const legacyMap = {
      0: (0, -1),
      1: (1, 0),
      2: (1, 1),
      3: (1, 2),
      4: (3, -1),
      5: (2, 0),
      6: (2, 1),
      7: (1, 3),
      8: (1, 4),
    };

    final mapped = legacyMap[tab] ?? (0, -1);
    if (mounted) {
      setState(() => _currentIndex = mapped.$1);
      if (mapped.$2 >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _accountsKey.currentState?.jumpToTab(mapped.$2);
        });
      }
    }
    NotificationNavigationService.clearAdminTab();
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

  Future<void> _openSettingsDrawer() async {
    setState(() => _drawerLoading = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/app_settings.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map? ?? {};
        setState(() {
          _evEnabled = data['email_verification_enabled'] == true;
          _spEnabled = data['strong_password_enabled'] == true;
          _maxSessionDays =
              (data['max_session_days'] as num?)?.toInt() ?? 3;
          _evOriginal = _evEnabled;
          _spOriginal = _spEnabled;
          _maxSessionDaysOriginal = _maxSessionDays;
        });
      }
    } catch (_) {}
    setState(() => _drawerLoading = false);
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _saveDrawerSettings() async {
    setState(() => _drawerSaving = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post('/admin/settings.php', data: {
        'email_verification_enabled': _evEnabled,
        'strong_password_enabled': _spEnabled,
        'max_session_days': _maxSessionDays,
      });
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        _scaffoldKey.currentState?.closeDrawer();
        if (mounted) AppSnackBar.info(context, 'تم حفظ الإعدادات.');
      }
    } catch (_) {}
    setState(() => _drawerSaving = false);
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Text('الإعدادات',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_drawerLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _evEnabled,
                            onChanged: (v) => setState(() => _evEnabled = v),
                            title: const Text('التحقق من البريد الإلكتروني'),
                            subtitle: const Text('إرسال كود تحقق عند التسجيل',
                                style: TextStyle(fontSize: 12)),
                            secondary: const Icon(
                                Icons.mark_email_read_outlined,
                                color: Colors.teal),
                            activeThumbColor: Colors.teal,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _spEnabled,
                            onChanged: (v) => setState(() => _spEnabled = v),
                            title: const Text('كلمة المرور القوية'),
                            subtitle: const Text('8 أحرف + حرف كبير + رقم',
                                style: TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.lock_outlined,
                                color: Colors.teal),
                            activeThumbColor: Colors.teal,
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined,
                                    color: Colors.teal),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('أيام الجلسات الأسبوعية'),
                                      Text(
                                        'الحد الأقصى لأيام الطالب (1–5)',
                                        style: TextStyle(fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: _maxSessionDays > 1
                                      ? Colors.teal
                                      : Colors.grey,
                                  onPressed: _maxSessionDays > 1
                                      ? () => setState(
                                          () => _maxSessionDays--)
                                      : null,
                                ),
                                Text(
                                  '$_maxSessionDays',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: _maxSessionDays < 5
                                      ? Colors.teal
                                      : Colors.grey,
                                  onPressed: _maxSessionDays < 5
                                      ? () => setState(
                                          () => _maxSessionDays++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_settingsChanged)
                      ElevatedButton(
                        onPressed: _drawerSaving ? null : _saveDrawerSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _drawerSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('حفظ'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.closeDrawer(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('عودة'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSettingsDrawer(),
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'الإعدادات',
          onPressed: _openSettingsDrawer,
        ),
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: PopupMenuButton<String>(
              tooltip: 'القائمة',
              onSelected: _onMenuSelected,
              offset: const Offset(0, 48),
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
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'الحسابات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'المتابعة',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'التواصل',
          ),
        ],
      ),
    );
  }
}
