import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;
  String _role = '';
  bool _reminders = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/profile.php');
      final body = response.data;
      if (body is! Map || body['ok'] != true) throw Exception();
      final user = body['data']?['user'] as Map?;
      if (!mounted) return;
      setState(() {
        _role = user?['role']?.toString() ?? '';
        _reminders = user?['session_reminders'] != false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تحميل الإعدادات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setReminders(bool enabled) async {
    if (_saving) return;
    final previous = _reminders;
    setState(() {
      _saving = true;
      _reminders = enabled;
    });

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.post(
        '/notifications/reminder_setting.php',
        data: {'enabled': enabled},
      );
      final body = response.data;
      if (body is! Map || body['ok'] != true) throw Exception();
    } catch (_) {
      if (!mounted) return;
      setState(() => _reminders = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الإعداد، حاول مرة أخرى')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 4, bottom: 8),
                      child: Text(
                        'التنبيهات',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text(
                          'تذكير مواعيد الجلسات',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _role == 'teacher'
                              ? 'تنبيه عند حلول وقت الجلسة وعند دخول كل طالب'
                              : 'تنبيه عند حلول وقت جلستك',
                        ),
                        value: _reminders,
                        onChanged: _saving ? null : _setReminders,
                      ),
                    ),
                  ],
                ),
    );
  }
}
