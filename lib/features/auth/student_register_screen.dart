import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/password_strength_indicator.dart';
import 'verify_email_screen.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _gender = 'male';
  String _level = 'beginner';
  String _readingType = 'hafs_an_asim';
  String _preferredPeriod = 'after_asr';

  bool _loading = false;
  String _passwordText = '';
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    AppSettingsService.load();
    _passwordController.addListener(() {
      setState(() => _passwordText = _passwordController.text);
    });
  }

  Future<void> _handleSuccessAndBack(String message) async {
    setState(() {
      _success = message;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.of(context).pop(message);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/register_student.php',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'address': _addressController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'gender': _gender,
          'level': _level,
          'reading_type': _readingType,
          'preferred_period': _preferredPeriod,
        },
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        final data = body['data'] as Map? ?? {};
        if (data['needs_verification'] == true) {
          final userId = data['user_id'] as int? ?? 0;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(
                userId: userId,
                email: _emailController.text.trim(),
                name: _nameController.text.trim(),
              ),
            ),
          );
          return;
        }

        final successMessage =
            body['message']?.toString() ?? 'تم إرسال طلب تسجيل الطالب بنجاح';
        await _handleSuccessAndBack(successMessage);
      } else {
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر إتمام التسجيل';
        });
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      if (e.response?.data is Map) {
        message = e.response?.data['message']?.toString() ?? message;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'انتهت مهلة الاتصال، حاول مرة أخرى';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'تحقق من الاتصال بالإنترنت';
      }

      setState(() {
        _error = message;
      });
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ غير متوقع';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  List<DropdownMenuItem<String>> _periodItems() {
    return AppLabels.periodsList()
        .map(
          (period) => DropdownMenuItem<String>(
            value: period,
            child: Text(
              AppLabels.period(period),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  List<DropdownMenuItem<String>> _qiraaItems() {
    return AppLabels.qiraatList()
        .map(
          (qiraa) => DropdownMenuItem<String>(
            value: qiraa,
            child: Text(
              AppLabels.qiraa(qiraa),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل طالب جديد'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'إنشاء حساب طالب',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أدخل بياناتك وسيتم إرسال طلبك للمراجعة',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('الاسم الكامل'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل الاسم';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('البريد الإلكتروني'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل البريد الإلكتروني';
                          }
                          if (!value.contains('@')) {
                            return 'أدخل بريدًا إلكترونيًا صحيحًا';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _inputDecoration('كلمة المرور'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'أدخل كلمة المرور';
                          if (AppSettingsService.strongPasswordEnabled) {
                            if (value.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                            if (!value.contains(RegExp(r'[A-Z]'))) return 'أضف حرفاً كبيراً (A-Z)';
                            if (!value.contains(RegExp(r'[a-z]'))) return 'أضف حرفاً صغيراً (a-z)';
                            if (!value.contains(RegExp(r'[0-9]'))) return 'أضف رقماً (0-9)';
                          } else {
                            if (value.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      if (AppSettingsService.strongPasswordEnabled)
                        PasswordStrengthIndicator(password: _passwordText),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: _inputDecoration('تأكيد كلمة المرور'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'أعد إدخال كلمة المرور';
                          }
                          if (value != _passwordController.text) {
                            return 'كلمتا المرور غير متطابقتين';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        decoration: _inputDecoration('العنوان'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل العنوان';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('العمر'),
                        validator: (value) {
                          final age = int.tryParse(value?.trim() ?? '');
                          if (age == null || age <= 0) {
                            return 'أدخل عمرًا صحيحًا';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        isExpanded: true,
                        decoration: _inputDecoration('الجنس'),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('ذكر')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('أنثى'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _gender = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _level,
                        isExpanded: true,
                        decoration: _inputDecoration('المستوى'),
                        items: const [
                          DropdownMenuItem(
                            value: 'beginner',
                            child: Text('مبتدئ'),
                          ),
                          DropdownMenuItem(
                            value: 'intermediate',
                            child: Text('متوسط'),
                          ),
                          DropdownMenuItem(
                            value: 'advanced',
                            child: Text('متقدم'),
                          ),
                          DropdownMenuItem(
                            value: 'new_reading',
                            child: Text('قراءة جديدة'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _level = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _readingType,
                        isExpanded: true,
                        menuMaxHeight: 420,
                        decoration: _inputDecoration('القراءة المطلوبة'),
                        items: _qiraaItems(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _readingType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _preferredPeriod,
                        isExpanded: true,
                        decoration: _inputDecoration('الفترة المفضلة'),
                        items: _periodItems(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _preferredPeriod = value;
                            });
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
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            _success!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('إرسال طلب التسجيل'),
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
    );
  }
}
