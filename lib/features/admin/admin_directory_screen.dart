import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import 'dart:async';
import '../../core/utils/admin_refresh_notifier.dart';
import '../../core/ui/app_snackbar.dart';

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

  int? _extractUserId(Map user) {
    return user['user_id'] ??
        user['id'] ??
        user['student_id'] ??
        user['teacher_id'];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    /// 🔥 تحديث فوري عند أي تغيير (حذف / استرجاع / قبول)
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
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

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

        setState(() {
          students = studentsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          teachers = teachersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          _loading = false;
        });
      } else {
        setState(() {
          _error = 'تعذر تحميل البيانات';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      }

      if (mounted) {
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع';
          _loading = false;
        });
      }
    }
  }

  // ================================
  // 🔥 حذف المستخدم (نهائي ومحسّن)
  // ================================
  Future<void> _deleteUser(Map user) async {
    final userId = _extractUserId(user);

    if (userId == null) {
      AppSnackBar.error(context, 'تعذر تحديد المستخدم');
      return;
    }

    try {
      final dio = await ApiClient.getInstance();

      // 🔥 تحقق قبل الحذف
      final checkRes = await dio.post(
        '/admin/manage_user.php',
        data: FormData.fromMap({
          'user_id': userId.toString(),
          'action': 'check_delete',
        }),
      );

      final body = checkRes.data;

      if (body is! Map) {
        AppSnackBar.error(context, 'استجابة غير صالحة من الخادم');
        return;
      }

      if (body['ok'] != true) {
        AppSnackBar.error(
          context,
          body['message']?.toString() ?? 'لا يمكن الحذف',
        );
        return;
      }

      // 🔥 طلب السبب
      final controller = TextEditingController();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('سبب الحذف'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'اكتب سبب الحذف...',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('حذف'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      // 🔥 تنفيذ الحذف
      final res = await dio.post(
        '/admin/manage_user.php',
        data: FormData.fromMap({
          'user_id': userId.toString(),
          'action': 'delete',
          'reason': controller.text.trim(),
        }),
      );

      final resBody = res.data;

      if (resBody is Map && resBody['ok'] == true) {
        AppSnackBar.success(context, 'تم الحذف');

        /// 🔥 تحديث فوري لكل الشاشات
        AdminRefreshNotifier.notify();

        /// 🔥 تحديث فوري داخل نفس الشاشة (بدون انتظار API)
        setState(() {
          students.removeWhere((u) => _extractUserId(u) == userId);
          teachers.removeWhere((u) => _extractUserId(u) == userId);
        });
      } else {
        AppSnackBar.error(
          context,
          resBody is Map
              ? resBody['message']?.toString() ?? 'فشل الحذف'
              : 'فشل الحذف',
        );
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      final data = e.response?.data;

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      }

      AppSnackBar.error(context, message);
    } catch (_) {
      AppSnackBar.error(context, 'خطأ غير متوقع');
    }
  }

  void _showUserOptions(Map user) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteUser(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get filteredStudents {
    if (studentQuery.trim().isEmpty) return students;
    final q = studentQuery.toLowerCase().trim();

    return students.where((m) {
      return (m['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['email']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredTeachers {
    if (teacherQuery.trim().isEmpty) return teachers;
    final q = teacherQuery.toLowerCase().trim();

    return teachers.where((m) {
      return (m['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['email']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Widget _studentCard(Map<String, dynamic> item) {
    final teacherName = item['teacher_name']?.toString().trim();

    return GestureDetector(
      onTap: () => _showUserOptions(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('البريد: ${item['email']}'),
              Text('المستوى: ${AppLabels.level(item['level']?.toString())}'),
              Text(
                'القراءة: ${AppLabels.qiraa(item['reading_type']?.toString())}',
              ),
              Text(
                'الفترة: ${AppLabels.period(item['preferred_period']?.toString())}',
              ),
              Text(
                'المُقرئ: ${teacherName == null || teacherName.isEmpty ? 'غير مرتبط' : teacherName}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teacherCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showUserOptions(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('البريد: ${item['email']}'),
              Text('القراءات: ${AppLabels.qiraatText(item['readings'])}'),
              Text(
                'الفترات: ${AppLabels.periodsText(item['available_periods'])}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _studentsTab() {
    final list = filteredStudents;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
          child: list.isEmpty
              ? const Center(child: Text('لا يوجد طلاب'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _studentCard(list[i]),
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
          padding: const EdgeInsets.all(16),
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
          child: list.isEmpty
              ? const Center(child: Text('لا يوجد مُقرئون'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _teacherCard(list[i]),
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
      return Center(child: Text(_error!));
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الطلاب'),
            Tab(text: 'المُقرئون'),
          ],
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
    return Scaffold(body: _buildBody());
  }
}