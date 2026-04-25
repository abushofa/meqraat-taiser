import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';

import 'admin_dashboard_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_sessions_screen.dart';
import 'admin_pending_requests_screen.dart';
import 'admin_assignments_screen.dart';
import 'admin_manage_students_screen.dart';
import 'admin_directory_screen.dart';
import '../profile/profile_screen.dart';

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _currentIndex = 0;
  final ScrollController _navScrollController = ScrollController();

  final List<Widget> _pages = const [
    AdminDashboardScreen(),
    AdminReportsScreen(),
    AdminSessionsScreen(),
    AdminPendingRequestsScreen(),
    AdminAssignmentsScreen(),
    AdminManageStudentsScreen(),
    AdminDirectoryScreen(),
  ];

  final List<String> _titles = const [
    'لوحة المشرف',
    'التقارير',
    'الجلسات',
    'الطلبات',
    'الربط',
    'إدارة الطلاب',
    'الدليل',
  ];

  @override
  void dispose() {
    _navScrollController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      final dio = await ApiClient.getInstance();
      await dio.post('/logout.php');
    } catch (_) {}

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
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
    }
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _changeTab(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 82),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0F766E).withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F766E).withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 86, // ✅ تم رفعه لحل overflow
          child: SingleChildScrollView(
            controller: _navScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'الرئيسية',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: 'التقارير',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.history_outlined,
                  selectedIcon: Icons.history,
                  label: 'الجلسات',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.pending_actions_outlined,
                  selectedIcon: Icons.pending_actions,
                  label: 'الطلبات',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.link_outlined,
                  selectedIcon: Icons.link,
                  label: 'الربط',
                  index: 4,
                ),
                _buildNavItem(
                  icon: Icons.manage_accounts_outlined,
                  selectedIcon: Icons.manage_accounts,
                  label: 'الإدارة',
                  index: 5,
                ),
                _buildNavItem(
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  label: 'الدليل',
                  index: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}