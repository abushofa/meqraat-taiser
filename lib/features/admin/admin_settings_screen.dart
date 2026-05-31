import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _emailVerification = false;
  bool _strongPassword = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/app_settings.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map? ?? {};
        setState(() {
          _emailVerification = data['email_verification_enabled'] == true;
          _strongPassword    = data['strong_password_enabled'] == true;
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post('/admin/settings.php', data: {
        'email_verification_enabled': _emailVerification,
        'strong_password_enabled':    _strongPassword,
      });
      final body = res.data;
      if (!mounted) return;
      if (body is Map && body['ok'] == true) {
        AppSnackBar.info(context, 'تم حفظ الإعدادات بنجاح.');
        Navigator.of(context).pop();
      } else {
        AppSnackBar.error(context, (body is Map ? body['message'] : null)?.toString() ?? 'فشل الحفظ.');
      }
    } on DioException catch (_) {
      if (mounted) AppSnackBar.error(context, 'فشل الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionCard(
                    title: 'التسجيل والأمان',
                    icon: Icons.security_outlined,
                    children: [
                      SwitchListTile(
                        value: _emailVerification,
                        onChanged: (v) => setState(() => _emailVerification = v),
                        title: const Text('التحقق من البريد الإلكتروني'),
                        subtitle: const Text(
                          'عند التفعيل يُرسَل كود للمستخدم الجديد ويجب إدخاله قبل تسجيل الدخول',
                          style: TextStyle(fontSize: 12),
                        ),
                        secondary: const Icon(Icons.mark_email_read_outlined, color: Colors.teal),
                        activeThumbColor: Colors.teal,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _strongPassword,
                        onChanged: (v) => setState(() => _strongPassword = v),
                        title: const Text('اشتراطات كلمة المرور القوية'),
                        subtitle: const Text(
                          '8 أحرف على الأقل + حرف كبير + حرف صغير + رقم',
                          style: TextStyle(fontSize: 12),
                        ),
                        secondary: const Icon(Icons.lock_outlined, color: Colors.teal),
                        activeThumbColor: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('حفظ الإعدادات', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.teal),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
