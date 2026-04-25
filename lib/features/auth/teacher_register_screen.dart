import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';

class TeacherRegisterScreen extends StatefulWidget {
  const TeacherRegisterScreen({super.key});

  @override
  State<TeacherRegisterScreen> createState() => _TeacherRegisterScreenState();
}

class _TeacherRegisterScreenState extends State<TeacherRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();

  String _gender = 'male';

  final Set<String> _availablePeriods = {'after_asr'};
  final Set<String> _selectedQiraat = {'hafs_an_asim'};
  bool _allQiraat = false;

  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _handleSuccessAndBack(String message) async {
    setState(() {
      _success = message;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.of(context).pop(message);
  }

  void _togglePeriod(String period, bool? selected) {
    setState(() {
      if (selected == true) {
        _availablePeriods.add(period);
      } else {
        _availablePeriods.remove(period);
      }
    });
  }

  void _toggleQiraa(String qiraa, bool? selected) {
    setState(() {
      if (_allQiraat) return;

      if (selected == true) {
        _selectedQiraat.add(qiraa);
      } else {
        _selectedQiraat.remove(qiraa);
      }
    });
  }

  void _toggleAllQiraat(bool? selected) {
    setState(() {
      _allQiraat = selected == true;

      if (_allQiraat) {
        _selectedQiraat.clear();
      } else if (_selectedQiraat.isEmpty) {
        _selectedQiraat.add('hafs_an_asim');
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_availablePeriods.isEmpty) {
      setState(() {
        _error = 'اختر فترة توفر واحدة على الأقل';
        _success = null;
      });
      return;
    }

    if (!_allQiraat && _selectedQiraat.isEmpty) {
      setState(() {
        _error = 'اختر قراءة واحدة على الأقل';
        _success = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final dio = await ApiClient.getInstance();

      final response = await dio.post(
        '/register_teacher.php',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'address': _addressController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'gender': _gender,
          'readings': _allQiraat ? 'all_qiraat' : _selectedQiraat.join(','),
          'available_periods': _availablePeriods.join(','),
        },
      );

      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;

        final successMessage =
            body['message']?.toString() ?? 'تم إرسال طلب تسجيل المُقرئ بنجاح';

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

  Widget _periodCheckbox(String period) {
    return CheckboxListTile(
      value: _availablePeriods.contains(period),
      onChanged: _loading ? null : (value) => _togglePeriod(period, value),
      title: Text(AppLabels.period(period)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _qiraaCheckbox(String qiraa) {
    return CheckboxListTile(
      value: _selectedQiraat.contains(qiraa),
      onChanged: (_loading || _allQiraat)
          ? null
          : (value) => _toggleQiraa(qiraa, value),
      title: Text(AppLabels.qiraa(qiraa), style: const TextStyle(height: 1.35)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: false,
      isThreeLine: false,
    );
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
      appBar: AppBar(title: const Text('التسجيل كمُقرئ'), centerTitle: true),
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
                        'إنشاء حساب مُقرئ',
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
                          if (value == null || value.isEmpty) {
                            return 'أدخل كلمة المرور';
                          }
                          if (value.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
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
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'القراءات التي تُتقنها',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: _allQiraat,
                              onChanged: _loading ? null : _toggleAllQiraat,
                              title: const Text('جميع القراءات'),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            const Divider(),
                            ...AppLabels.qiraatList().map(_qiraaCheckbox),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'فترات التوفر',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _periodCheckbox('after_fajr'),
                            _periodCheckbox('after_dhuhr'),
                            _periodCheckbox('after_asr'),
                            _periodCheckbox('after_maghrib'),
                            _periodCheckbox('after_isha'),
                          ],
                        ),
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
