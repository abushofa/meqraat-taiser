import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../student/student_home_shell.dart';
import '../teacher/teacher_home_shell.dart';
import '../admin/admin_home_shell.dart';
import 'student_register_screen.dart';
import 'teacher_register_screen.dart';
import '../../core/storage/session_storage.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/device_info_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(const Duration(milliseconds: 120), () async {
      if (!mounted) return;
      await _introController.forward();
      if (!mounted) return;
      _pulseController.repeat(reverse: true);
    });

    // إذا كانت هناك جلسة سابقة لم تُغلق بشكل صحيح، امسح الـ token من السيرفر
    // حتى لا يُمنع المستخدم من الدخول على جهاز آخر لاحقاً
    _clearStaleSession();
  }

  Future<void> _clearStaleSession() async {
    final wasLoggedIn = await SessionStorage.isLoggedIn();
    if (!wasLoggedIn) return;
    await SessionStorage.clear();
    try {
      final dio = await ApiClient.getInstance();
      await dio.post(
        '/logout.php',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } catch (_) {}
  }

  Future<void> _login({bool force = false}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'أدخل البريد الإلكتروني وكلمة المرور';
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final deviceName = await DeviceInfoHelper.getDeviceName();
    final deviceId   = await DeviceInfoHelper.getDeviceId();

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/login.php',
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
          'device_id': deviceId,
          if (force) 'force': true,
        },
      );

      final data = response.data;

      if (data is Map && data['ok'] == true) {
        final user = data['data']?['user'];
        final role = user?['role'];
        await SessionStorage.setLoggedIn(true);
        PushNotificationService.registerTokenAfterLogin();

        if (!mounted) return;

        if (role == 'student') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StudentHomeShell()),
          );
        } else if (role == 'teacher') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TeacherHomeShell()),
          );
        } else if (role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminHomeShell()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RoleHomeScreen(role: role?.toString() ?? ''),
            ),
          );
        }
      } else {
        setState(() {
          _error =
              (data is Map ? data['message'] : null)?.toString() ??
              'فشل تسجيل الدخول';
        });
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      // مسجّل على جهاز آخر
      if (e.response?.statusCode == 409 &&
          e.response?.data is Map &&
          e.response!.data['error']?['already_logged_in'] == true) {
        final otherDevice =
            e.response!.data['error']?['device_name']?.toString() ??
            'جهاز غير معروف';
        if (mounted) {
          setState(() => _loading = false);
          _showAlreadyLoggedInDialog(otherDevice);
        }
        return;
      }

      if (e.response?.statusCode == 401) {
        message = 'بيانات الدخول غير صحيحة';
      } else if (e.response?.data is Map) {
        message = e.response?.data['message']?.toString() ?? message;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'انتهت مهلة الاتصال، حاول مرة أخرى';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'تحقق من الاتصال بالإنترنت';
      } else if (e.type == DioExceptionType.badCertificate) {
        message = 'تعذر التحقق من أمان الاتصال';
      } else if (e.type == DioExceptionType.cancel) {
        message = 'تم إلغاء الطلب';
      }

      if (mounted) {
        setState(() {
          _error = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showAlreadyLoggedInDialog(String otherDevice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('أنت مسجّل الدخول بالفعل'),
        content: Text(
          'تم تسجيل دخولك مسبقاً على:\n\n$otherDevice\n\nهل تريد تسجيل الخروج منه والدخول من هذا الجهاز؟',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _login(force: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('ادخل من هنا', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _goToStudentRegister() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const StudentRegisterScreen()),
    );

    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _success = result;
        _error = null;
      });
    }
  }

  Future<void> _goToTeacherRegister() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TeacherRegisterScreen()),
    );

    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _success = result;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 390;
    final logoOuter = isSmall ? 92.0 : 104.0;
    final logoInner = isSmall ? 66.0 : 74.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        const SizedBox(height: 6),

                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _introController,
                            _pulseController,
                          ]),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnim.value * _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: logoOuter,
                            height: logoOuter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF1F5F9),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F766E,
                                  ).withValues(alpha: 0.10),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(
                                  0xFF0F766E,
                                ).withValues(alpha: 0.08),
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: logoInner,
                                height: logoInner,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'مقرأة التيسير الإلكترونية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 20 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'سجل الدخول للمتابعة',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            if (!_loading) {
                              _login();
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        if (_error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),

                        if (_success != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                              ),
                            ),
                            child: Text(
                              _success!,
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('دخول'),
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 8),

                        const Text(
                          'ليس لديك حساب؟',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _goToStudentRegister,
                            icon: const Icon(Icons.school_outlined),
                            label: const Text('تسجيل طالب جديد'),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _goToTeacherRegister,
                            icon: const Icon(Icons.record_voice_over_outlined),
                            label: const Text('التسجيل كمُقرئ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleHomeScreen extends StatelessWidget {
  final String role;

  const RoleHomeScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    String title = 'غير معروف';

    if (role == 'student') {
      title = 'لوحة الطالب';
    } else if (role == 'teacher') {
      title = 'لوحة المُقرئ';
    } else if (role == 'admin') {
      title = 'لوحة المشرف';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(
        child: Text(
          'تم تسجيل الدخول بنجاح\nالدور: $role',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}