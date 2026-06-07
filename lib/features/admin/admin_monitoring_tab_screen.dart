import 'package:flutter/material.dart';

import 'admin_sessions_screen.dart';
import 'admin_reports_screen.dart';

class AdminMonitoringTabScreen extends StatefulWidget {
  const AdminMonitoringTabScreen({super.key});

  @override
  State<AdminMonitoringTabScreen> createState() =>
      _AdminMonitoringTabScreenState();
}

class _AdminMonitoringTabScreenState extends State<AdminMonitoringTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(text: 'الجلسات'),
    Tab(text: 'التقارير'),
  ];

  static const _screens = [
    AdminSessionsScreen(),
    AdminReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
