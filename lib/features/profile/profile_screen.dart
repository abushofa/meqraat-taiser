import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/app_labels.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/ui/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/profile.php');
      final body = response.data;

      if (body is Map && body['ok'] == true) {
        if (!mounted) return;
        setState(() {
          _data = Map<String, dynamic>.from(body['data'] as Map);
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error =
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحميل الحساب';
        });
      }
    } on DioException catch (e) {
      String message = 'فشل الاتصال بالخادم';

      if (e.response?.data is Map) {
        message = e.response?.data['message']?.toString() ?? message;
      }

      if (!mounted) return;
      setState(() {
        _error = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ غير متوقع';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'student':
        return 'طالب';
      case 'teacher':
        return 'مُقرئ';
      case 'admin':
        return 'مشرف';
      default:
        return role ?? '—';
    }
  }

  bool _canEdit(String role) => role == 'student' || role == 'teacher';

  Future<void> _openEditProfile() async {
    final user = _data?['user'] as Map<String, dynamic>?;
    final extra = _data?['extra'] as Map<String, dynamic>?;
    final role = user?['role']?.toString() ?? '';

    if (!_canEdit(role) || user == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          role: role,
          user: Map<String, dynamic>.from(user),
          extra: extra != null ? Map<String, dynamic>.from(extra) : {},
        ),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Icon(icon, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _buildExtraSection(
    String role,
    Map<String, dynamic>? extra,
  ) {
    if (extra == null) {
      return [
        _infoTile('البيانات', 'لا توجد بيانات إضافية'),
      ];
    }

    if (role == 'student') {
      return [
        _infoTile('الحالة', AppLabels.status(extra['status']?.toString())),
        _infoTile('العنوان', '${extra['address'] ?? '—'}'),
        _infoTile('العمر', '${extra['age'] ?? '—'}'),
        _infoTile('الجنس', AppLabels.gender(extra['gender']?.toString())),
        _infoTile('المستوى', AppLabels.level(extra['level']?.toString())),
        _infoTile(
          'القراءة',
          AppLabels.qiraa(extra['reading_type']?.toString()),
        ),
        _infoTile(
          'الفترة المفضلة',
          AppLabels.period(extra['preferred_period']?.toString()),
        ),
      ];
    }

    if (role == 'teacher') {
      return [
        _infoTile('الحالة', AppLabels.status(extra['status']?.toString())),
        _infoTile('العنوان', '${extra['address'] ?? '—'}'),
        _infoTile('العمر', '${extra['age'] ?? '—'}'),
        _infoTile('الجنس', AppLabels.gender(extra['gender']?.toString())),
        _infoTile('القراءات', AppLabels.qiraatText(extra['readings'])),
        _infoTile(
          'فترات التوفر',
          AppLabels.periodsText(extra['available_periods']),
        ),
        _infoTile('عدد الطلاب', '${extra['students_count'] ?? 0}'),
      ];
    }

    return [
      _infoTile('الحالة', '${extra['status'] ?? 'نشط'}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = _data?['user'] as Map<String, dynamic>?;
    final extra = _data?['extra'] as Map<String, dynamic>?;
    final role = user?['role']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحساب'),
        centerTitle: true,
        actions: [
          if (_canEdit(role))
            IconButton(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل البيانات',
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _sectionCard(
                        title: 'البيانات الأساسية',
                        icon: Icons.person_outline,
                        children: [
                          _infoTile('الاسم', '${user?['name'] ?? '—'}'),
                          _infoTile('البريد', '${user?['email'] ?? '—'}'),
                          _infoTile('الدور', _roleLabel(role)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionCard(
                        title: 'بيانات إضافية',
                        icon: Icons.badge_outlined,
                        children: _buildExtraSection(role, extra),
                      ),
                      if (_canEdit(role)) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openEditProfile,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('تعديل البيانات'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String role;
  final Map<String, dynamic> user;
  final Map<String, dynamic> extra;

  const EditProfileScreen({
    super.key,
    required this.role,
    required this.user,
    required this.extra,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _ageController;

  String _gender = 'male';
  String _level = 'beginner';
  String _readingType = 'hafs_an_asim';
  String _preferredPeriod = 'after_asr';

  final Set<String> _teacherReadings = {};
  final Set<String> _teacherPeriods = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user['name']?.toString() ?? '',
    );
    _addressController = TextEditingController(
      text: widget.extra['address']?.toString() ?? '',
    );
    _ageController = TextEditingController(
      text: widget.extra['age']?.toString() ?? '',
    );

    _gender = widget.extra['gender']?.toString() ?? 'male';

    if (widget.role == 'student') {
      _level = widget.extra['level']?.toString() ?? 'beginner';
      _readingType = widget.extra['reading_type']?.toString() ?? 'hafs_an_asim';
      _preferredPeriod =
          widget.extra['preferred_period']?.toString() ?? 'after_asr';
    }

    if (widget.role == 'teacher') {
      final rawReadings = (widget.extra['readings'] ?? '').toString().trim();
      final rawPeriods =
          (widget.extra['available_periods'] ?? '').toString().trim();

      if (rawReadings.isNotEmpty) {
        _teacherReadings.addAll(
          rawReadings
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }

      if (rawPeriods.isNotEmpty) {
        _teacherPeriods.addAll(
          rawPeriods
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }

      if (_teacherReadings.isEmpty) {
        _teacherReadings.add('hafs_an_asim');
      }

      if (_teacherPeriods.isEmpty) {
        _teacherPeriods.add('after_asr');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  void _toggleTeacherReading(String value, bool? checked) {
    setState(() {
      if (value == 'all_qiraat') {
        if (checked == true) {
          _teacherReadings
            ..clear()
            ..add('all_qiraat');
        } else {
          _teacherReadings.remove('all_qiraat');
          if (_teacherReadings.isEmpty) {
            _teacherReadings.add('hafs_an_asim');
          }
        }
        return;
      }

      if (_teacherReadings.contains('all_qiraat')) {
        _teacherReadings.remove('all_qiraat');
      }

      if (checked == true) {
        _teacherReadings.add(value);
      } else {
        _teacherReadings.remove(value);
      }

      if (_teacherReadings.isEmpty) {
        _teacherReadings.add('hafs_an_asim');
      }
    });
  }

  void _toggleTeacherPeriod(String value, bool? checked) {
    setState(() {
      if (checked == true) {
        _teacherPeriods.add(value);
      } else {
        _teacherPeriods.remove(value);
      }

      if (_teacherPeriods.isEmpty) {
        _teacherPeriods.add('after_asr');
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.role == 'teacher' && _teacherReadings.isEmpty) {
      await AppDialogs.showInfo(
        context: context,
        title: 'القراءات',
        message: 'اختر قراءة واحدة على الأقل.',
        icon: Icons.menu_book_outlined,
        iconColor: Colors.orange,
      );
      return;
    }

    if (widget.role == 'teacher' && _teacherPeriods.isEmpty) {
      await AppDialogs.showInfo(
        context: context,
        title: 'فترات التوفر',
        message: 'اختر فترة توفر واحدة على الأقل.',
        icon: Icons.schedule_outlined,
        iconColor: Colors.orange,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final dio = await ApiClient.getInstance();

      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
      };

      if (widget.role == 'student') {
        data.addAll({
          'address': _addressController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'gender': _gender,
          'level': _level,
          'reading_type': _readingType,
          'preferred_period': _preferredPeriod,
        });
      } else if (widget.role == 'teacher') {
        data.addAll({
          'address': _addressController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'gender': _gender,
          'readings': _teacherReadings.toList(),
          'available_periods': _teacherPeriods.toList(),
        });
      }

      final response = await dio.post('/update_profile.php', data: data);
      final body = response.data;

      if (!mounted) return;

      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(
          context,
          body['message']?.toString() ?? 'تم تحديث الحساب بنجاح',
        );

        Navigator.pop(context, true);
      } else {
        await AppDialogs.showInfo(
          context: context,
          title: 'تعذر الحفظ',
          message:
              (body is Map ? body['message'] : null)?.toString() ??
              'تعذر تحديث الحساب',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      final data = e.response?.data;
      String message = 'فشل الاتصال بالخادم';

      if (data is Map) {
        message = data['message']?.toString() ?? message;
      }

      await AppDialogs.showInfo(
        context: context,
        title: 'فشل الحفظ',
        message: message,
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;

      await AppDialogs.showInfo(
        context: context,
        title: 'خطأ',
        message: 'حدث خطأ غير متوقع',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _periodRadio(String value) {
    return RadioListTile<String>(
      value: value,
      groupValue: _preferredPeriod,
      onChanged: _saving
          ? null
          : (v) {
              if (v == null) return;
              setState(() {
                _preferredPeriod = v;
              });
            },
      title: Text(AppLabels.period(value)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _teacherReadingCheck(String value) {
    return CheckboxListTile(
      value: _teacherReadings.contains(value),
      onChanged: _saving ? null : (v) => _toggleTeacherReading(value, v),
      title: Text(
        value == 'all_qiraat' ? 'جميع القراءات' : AppLabels.qiraa(value),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _teacherPeriodCheck(String value) {
    return CheckboxListTile(
      value: _teacherPeriods.contains(value),
      onChanged: _saving ? null : (v) => _toggleTeacherPeriod(value, v),
      title: Text(AppLabels.period(value)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.role == 'student';
    final isTeacher = widget.role == 'teacher';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الحساب'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF6F8FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('الاسم'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل الاسم';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isStudent || isTeacher) ...[
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
                      decoration: _inputDecoration('الجنس'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('ذكر')),
                        DropdownMenuItem(value: 'female', child: Text('أنثى')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _gender = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isStudent) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _level,
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
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _level = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _readingType,
                      decoration: _inputDecoration('القراءة'),
                      items: AppLabels.qiraatList()
                          .map(
                            (q) => DropdownMenuItem(
                              value: q,
                              child: Text(AppLabels.qiraa(q)),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _readingType = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الفترة المفضلة',
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
                        children: AppLabels.periodsList()
                            .map(_periodRadio)
                            .toList(),
                      ),
                    ),
                  ],
                  if (isTeacher) ...[
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
                          _teacherReadingCheck('all_qiraat'),
                          const Divider(),
                          ...AppLabels.qiraatList().map(_teacherReadingCheck),
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
                        children: AppLabels.periodsList()
                            .map(_teacherPeriodCheck)
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}