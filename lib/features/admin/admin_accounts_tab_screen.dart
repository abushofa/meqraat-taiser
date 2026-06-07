import 'package:flutter/material.dart';

import 'admin_pending_requests_screen.dart';
import 'admin_assignments_screen.dart';
import 'admin_manage_students_screen.dart';
import 'admin_directory_screen.dart';
import 'admin_deleted_users_screen.dart';

class AdminAccountsTabScreen extends StatefulWidget {
  final int initialSubIndex;
  const AdminAccountsTabScreen({super.key, this.initialSubIndex = 0});

  @override
  State<AdminAccountsTabScreen> createState() => AdminAccountsTabScreenState();
}

class AdminAccountsTabScreenState extends State<AdminAccountsTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(text: 'الطلبات'),
    Tab(text: 'الربط'),
    Tab(text: 'الإدارة'),
    Tab(text: 'الدليل'),
    Tab(text: 'المحذوفون'),
  ];

  static const _screens = [
    AdminPendingRequestsScreen(),
    AdminAssignmentsScreen(),
    AdminManageStudentsScreen(),
    AdminDirectoryScreen(),
    AdminDeletedUsersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialSubIndex.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void jumpToTab(int index) {
    _tabController.animateTo(index.clamp(0, _tabs.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorColor: const Color(0xFF0F766E),
            labelColor: const Color(0xFF0F766E),
            dividerColor: Colors.grey.shade200,
            tabs: _tabs,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _screens,
          ),
        ),
      ],
    );
  }
}
