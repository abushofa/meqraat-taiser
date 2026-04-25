import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import 'dart:async';
import '../../core/utils/admin_refresh_notifier.dart';

class AdminDirectoryScreen extends StatefulWidget {
  const AdminDirectoryScreen({super.key});

  @override
  State<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends State<AdminDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> teachers = [];

  String studentQuery = '';
  String teacherQuery = '';

  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    _refreshSub = AdminRefreshNotifier.stream.listen((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();

      final studentsRes = await dio.get('/admin/manage_students_data.php');
      final teachersRes = await dio.get('/admin/manage_teachers_data.php');

      final studentsBody = studentsRes.data;
      final teachersBody = teachersRes.data;

      if (!mounted) return;

      if (studentsBody is Map &&
          studentsBody['ok'] == true &&
          teachersBody is Map &&
          teachersBody['ok'] == true) {
        final studentsRaw = studentsBody['data']?['students'] as List? ?? [];
        final teachersRaw = teachersBody['data']?['teachers'] as List? ?? [];

        final parsedStudents = studentsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final parsedTeachers = teachersRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          students = parsedStudents;
          teachers = parsedTeachers;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'تعذر تحميل البيانات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data is Map
            ? e.response?.data['message']?.toString() ?? 'فشل الاتصال بالخادم'
            : 'فشل الاتصال بالخادم';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ غير متوقع';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    if (studentQuery.trim().isEmpty) return students;
    final q = studentQuery.toLowerCase().trim();

    return students.where((m) {
      return (m['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['email']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['reading_type']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['teacher_name']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredTeachers {
    if (teacherQuery.trim().isEmpty) return teachers;
    final q = teacherQuery.toLowerCase().trim();

    return teachers.where((m) {
      return (m['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['email']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['readings']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Widget _studentCard(Map<String, dynamic> item) {
    final teacherName = item['teacher_name']?.toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('المستوى: ${AppLabels.level(item['level']?.toString())}'),
            Text(
              'القراءة: ${AppLabels.qiraa(item['reading_type']?.toString())}',
            ),
            Text(
              'الفترة المفضلة: ${AppLabels.period(item['preferred_period']?.toString())}',
            ),
            Text(
              'المُقرئ: ${teacherName == null || teacherName.isEmpty ? 'غير مرتبط' : teacherName}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('البريد: ${item['email'] ?? ''}'),
            Text('القراءات: ${AppLabels.qiraatText(item['readings'])}'),
            Text(
              'فترات التوفر: ${AppLabels.periodsText(item['available_periods'])}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentsTab() {
    final list = filteredStudents;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن طالب...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                studentQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('لا يوجد طلاب')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return _studentCard(list[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _teachersTab() {
    final list = filteredTeachers;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن مُقرئ...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                teacherQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('لا يوجد مُقرئون')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return _teacherCard(list[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'الطلاب'),
              Tab(text: 'المُقرئون'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_studentsTab(), _teachersTab()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: _buildBody(),
    );
  }
}
