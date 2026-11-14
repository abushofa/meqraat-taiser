import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/widgets/app_dialogs.dart';

/// مراسلة المقرئين والطلاب بالبريد الإلكتروني من حساب Gmail الخاص بالمقرأة.
class AdminEmailScreen extends StatefulWidget {
  const AdminEmailScreen({super.key});

  @override
  State<AdminEmailScreen> createState() => _AdminEmailScreenState();
}

enum _Mode { bcc, individual, single }

extension on _Mode {
  String get api => switch (this) {
        _Mode.bcc => 'bcc',
        _Mode.individual => 'individual',
        _Mode.single => 'single',
      };
  String get label => switch (this) {
        _Mode.bcc => 'جماعي',
        _Mode.individual => 'فردي للكل',
        _Mode.single => 'أشخاص محددون',
      };
  String get hint => switch (this) {
        _Mode.bcc =>
          'رسالة واحدة بنص عام، والمستلمون مخفيون عن بعضهم (BCC). لا يمكن استخدام {الاسم}.',
        _Mode.individual =>
          'رسالة مستقلة لكل شخص في الفئات المختارة باسمه، ولا يظهر له أنها أُرسلت لغيره.',
        _Mode.single =>
          'اختر طالبًا أو مقرئًا أو أكثر بالاسم؛ يستلم كل واحد رسالة مستقلة باسمه.',
      };
}

const _kName = '{الاسم}';
const _kColor = Color(0xFF0F766E);
// يجب أن تطابق ما في helpers/mail_helper.php على السيرفر
const _kSalam = 'السلام عليكم ورحمة الله وبركاته.';
const _kGreeting = '{التحية}'; // السيرفر يستبدله لكل مستلم حسب جنسه

/// التحية كما يكتبها السيرفر (للمعاينة فقط)
String _greetingFor(String name, String? gender) {
  final title = switch (gender) {
    'male' => 'الشيخ الفاضل',
    'female' => 'الشيخة الفاضلة',
    _ => 'الشيخ(ة) الفاضل(ة)',
  };
  return '$title $name\n$_kSalam';
}

class _AdminEmailScreenState extends State<AdminEmailScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _history = [];
  int _sentLast24h = 0;
  int _dailyLimit = 450;
  String _from = '';

  _Mode _mode = _Mode.individual;
  final Set<String> _selectedGroups = {};
  final List<Map<String, dynamic>> _persons = [];
  bool _greeting = true;
  bool _testing = false;

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  /// التحية في أول الرسالة: باسم المستلم في الرسائل الفردية، وبلا اسم في الجماعية
  String get _greetingText => _mode == _Mode.bcc ? _kSalam : _kGreeting;

  /// النص الذي يُرسل فعلًا (التحية + ما كتبه المشرف)
  String get _fullBody {
    final b = _bodyCtrl.text.trim();
    return _greeting ? '$_greetingText\n\n$b' : b;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _groupLabel(String key) =>
      _groups.firstWhere((g) => g['key'] == key,
          orElse: () => {'label': key})['label'].toString();

  String _errorText(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
      return 'فشل الاتصال بالخادم';
    }
    return 'حدث خطأ غير متوقع';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.get('/admin/email_recipients.php');
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        final d = Map<String, dynamic>.from(body['data']);
        List<Map<String, dynamic>> list(String k) => ((d[k] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _groups = list('groups');
          _people = list('people');
          _history = list('history');
          _sentLast24h = (d['sent_last_24h'] as num?)?.toInt() ?? 0;
          _dailyLimit = (d['daily_limit'] as num?)?.toInt() ?? 450;
          _from = d['from']?.toString() ?? '';
          _persons.removeWhere(
              (s) => !_people.any((p) => p['user_id'] == s['user_id']));
        });
      } else {
        setState(() => _error = (body is Map ? body['message'] : null)
                ?.toString() ??
            'تعذر التحميل');
      }
    } catch (e) {
      setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// عدد المستلمين الفعلي (الإيميل المكرر بين فئتين يُحسب مرة واحدة)
  int get _recipientCount {
    if (_mode == _Mode.single) return _persons.length;
    return _people
        .where((p) => _selectedGroups.contains(p['group']))
        .map((p) => p['email'])
        .toSet()
        .length;
  }

  Map<String, dynamic>? get _firstRecipient {
    if (_mode == _Mode.single) return _persons.isEmpty ? null : _persons.first;
    for (final p in _people) {
      if (_selectedGroups.contains(p['group'])) return p;
    }
    return null;
  }

  void _insertAtCursor(String text) {
    final v = _bodyCtrl.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final newText = v.text.replaceRange(sel.start, sel.end, text);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text ?? '';
    if (t.isEmpty) {
      if (mounted) AppSnackBar.info(context, 'الحافظة فارغة');
      return;
    }
    _insertAtCursor(t);
  }

  String? _validate() {
    if (_mode == _Mode.single && _persons.isEmpty) {
      return 'اختر شخصًا واحدًا على الأقل';
    }
    if (_mode != _Mode.single && _selectedGroups.isEmpty) {
      return 'اختر فئة واحدة على الأقل';
    }
    if (_recipientCount == 0) return 'لا يوجد مستلمون في الفئات المختارة';
    if (_subjectCtrl.text.trim().isEmpty) return 'اكتب عنوان الرسالة';
    if (_bodyCtrl.text.trim().isEmpty) return 'اكتب نص الرسالة';
    if (_mode == _Mode.bcc &&
        (_bodyCtrl.text.contains(_kName) ||
            _subjectCtrl.text.contains(_kName))) {
      return 'الرسالة الجماعية واحدة للجميع، احذف {الاسم} أو اختر "فردي للكل"';
    }
    if (_sentLast24h + _recipientCount > _dailyLimit) {
      return 'تجاوز الحد اليومي: أُرسل إلى $_sentLast24h من $_dailyLimit خلال 24 ساعة';
    }
    return null;
  }

  void _preview() {
    final err = _validate();
    if (err != null) {
      AppSnackBar.warning(context, err);
      return;
    }
    final p = _firstRecipient!;
    final name = p['name'].toString();
    String fill(String s) => _mode == _Mode.bcc
        ? s
        : s
            .replaceAll(
                _kGreeting, _greetingFor(name, p['gender']?.toString()))
            .replaceAll(_kName, name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('معاينة'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('من: مقرأة التيسير <$_from>',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                  _mode == _Mode.bcc
                      ? 'إلى: (مخفي) — $_recipientCount مستلم'
                      : 'إلى: $name <${p['email']}>',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textDirection: TextDirection.rtl),
              const Divider(),
              Text(fill(_subjectCtrl.text.trim()),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(fill(_fullBody),
                  style: const TextStyle(height: 1.7)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final err = _validate();
    if (err != null) {
      AppSnackBar.warning(context, err);
      return;
    }
    final count = _recipientCount;
    final who = _mode == _Mode.single && count == 1
        ? 'إلى ${_persons.first['name']}'
        : 'إلى $count ${count == 1 ? 'شخص' : 'شخصًا'} (${_mode.label})';
    final ok = await AppDialogs.showConfirm(
      context: context,
      title: 'إرسال البريد',
      message: 'ستُرسل الرسالة $who.\nمتابعة؟',
      confirmText: 'إرسال',
      icon: Icons.send_outlined,
      iconColor: _kColor,
      confirmColor: _kColor,
    );
    if (!ok || !mounted) return;

    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post('/admin/send_email.php', data: {
        'action': 'start',
        'mode': _mode.api,
        'groups': _selectedGroups.toList(),
        if (_mode == _Mode.single)
          'user_ids': _persons.map((p) => p['user_id']).toList(),
        'subject': _subjectCtrl.text.trim(),
        'body': _fullBody,
      });
      final body = res.data;
      if (body is! Map || body['ok'] != true) {
        throw Exception((body is Map ? body['message'] : null) ?? 'تعذر البدء');
      }
      final logId = (body['data']['log_id'] as num).toInt();
      if (!mounted) return;
      final result = await _runProgress(logId, body['data']);
      if (!mounted) return;
      _showResult(result);
      if (result != null && result['done'] == true) {
        _subjectCtrl.clear();
        _bodyCtrl.clear();
        setState(() => _persons.clear());
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, e is DioException ? _errorText(e) : e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _load();
    }
  }

  /// نسخة واحدة إلى بريد المشرف نفسه، كما ستصل لأول مستلم
  Future<void> _sendTest() async {
    final err = _validate();
    if (err != null) {
      AppSnackBar.warning(context, err);
      return;
    }
    setState(() => _testing = true);
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post(
        '/admin/send_email.php',
        data: {
          'action': 'test',
          'subject': _subjectCtrl.text.trim(),
          'body': _fullBody,
          'sample_name':
              _mode == _Mode.bcc ? '' : _firstRecipient!['name'].toString(),
          'sample_gender': _mode == _Mode.bcc
              ? ''
              : (_firstRecipient!['gender']?.toString() ?? ''),
        },
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      final body = res.data;
      if (!mounted) return;
      if (body is Map && body['ok'] == true) {
        AppSnackBar.success(
            context, 'أُرسلت نسخة تجريبية إلى ${body['data']?['to'] ?? 'بريدك'}');
      } else {
        AppSnackBar.error(context,
            (body is Map ? body['message'] : null)?.toString() ?? 'فشل الإرسال');
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _errorText(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// يعرض نافذة التقدّم ويكرّر طلب continue حتى ينتهي الإرسال
  Future<Map<String, dynamic>?> _runProgress(
      int logId, Map initial) async {
    final progress = ValueNotifier<Map<String, dynamic>>(
        Map<String, dynamic>.from(initial));
    var cancelled = false;

    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('جارٍ الإرسال…'),
          content: ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: progress,
            builder: (_, p, _) {
              final total = (p['total'] as num?)?.toInt() ?? 0;
              final sent = (p['sent'] as num?)?.toInt() ?? 0;
              final failed = (p['failed'] as num?)?.toInt() ?? 0;
              final done = sent + failed;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                      value: total == 0 ? null : done / total, color: _kColor),
                  const SizedBox(height: 12),
                  Text('أُرسل $sent من $total'
                      '${failed > 0 ? ' — فشل $failed' : ''}'),
                  const SizedBox(height: 6),
                  const Text('لا تغلق التطبيق حتى ينتهي الإرسال',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text('إيقاف'),
            ),
          ],
        ),
      ),
    );

    Map<String, dynamic>? last = progress.value;
    var errors = 0;
    try {
      final dio = await ApiClient.getInstance();
      while (!cancelled && last?['done'] != true) {
        try {
          final res = await dio.post(
            '/admin/send_email.php',
            data: {'action': 'continue', 'log_id': logId},
            options: Options(receiveTimeout: const Duration(seconds: 120)),
          );
          final body = res.data;
          if (body is Map && body['ok'] == true) {
            last = Map<String, dynamic>.from(body['data']);
            progress.value = last;
            errors = 0;
          } else {
            errors++;
          }
        } catch (_) {
          errors++;
        }
        if (errors >= 3) break; // انقطاع متكرر: يمكن الاستئناف لاحقًا من السجل
        if (errors > 0) await Future.delayed(const Duration(seconds: 3));
      }
    } finally {
      if (!cancelled && mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      progress.dispose();
    }
    return last;
  }

  void _showResult(Map<String, dynamic>? r) {
    if (r == null) return;
    final total = (r['total'] as num?)?.toInt() ?? 0;
    final sent = (r['sent'] as num?)?.toInt() ?? 0;
    final failed = (r['failed'] as num?)?.toInt() ?? 0;
    final done = r['done'] == true;
    final lastError = r['last_error']?.toString();
    if (done && failed == 0) {
      AppSnackBar.success(context, 'تم الإرسال إلى $sent من $total');
      return;
    }
    AppDialogs.showInfo(
      context: context,
      title: done ? 'انتهى الإرسال مع أخطاء' : 'توقف الإرسال',
      message: 'أُرسل $sent من $total'
          '${failed > 0 ? '\nفشل: $failed' : ''}'
          '${!done ? '\nيمكنك متابعة الباقي من "سجل الرسائل".' : ''}'
          '${lastError != null && lastError.isNotEmpty ? '\n\nآخر خطأ: $lastError' : ''}',
    );
  }

  Future<void> _resume(Map<String, dynamic> h) async {
    Navigator.pop(context); // إغلاق السجل
    final result = await _runProgress((h['id'] as num).toInt(), h);
    if (!mounted) return;
    _showResult(result);
    _load();
  }

  void _openHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('سجل الرسائل',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: _history.isEmpty
                  ? const Center(
                      child: Text('لم تُرسل رسائل بعد',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scroll,
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final h = _history[i];
                        final mode = _Mode.values.firstWhere(
                            (m) => m.api == h['mode'],
                            orElse: () => _Mode.individual);
                        final groups = h['groups_text']
                            .toString()
                            .split(',')
                            .where((s) => s.isNotEmpty)
                            .map(_groupLabel)
                            .join('، ');
                        final unfinished = h['status'] != 'done';
                        return ListTile(
                          title: Text(h['subject'].toString()),
                          subtitle: Text(
                            '${mode.label} • $groups\n'
                            'أُرسل ${h['sent']} من ${h['total']}'
                            '${(h['failed'] as int) > 0 ? ' • فشل ${h['failed']}' : ''}'
                            ' • ${h['created_at']}',
                          ),
                          isThreeLine: true,
                          trailing: unfinished
                              ? TextButton(
                                  onPressed: () => _resume(h),
                                  child: const Text('متابعة'))
                              : Icon(
                                  (h['failed'] as int) > 0
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  color: (h['failed'] as int) > 0
                                      ? Colors.orange
                                      : _kColor),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _kColor)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  bool _isPicked(Map<String, dynamic> p) =>
      _persons.any((s) => s['user_id'] == p['user_id']);

  Widget _personPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _personSearch(),
        if (_persons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _persons)
                InputChip(
                  avatar: Icon(
                      p['group'].toString().startsWith('teachers')
                          ? Icons.menu_book_outlined
                          : Icons.school_outlined,
                      size: 18),
                  label: Text(p['name'].toString()),
                  tooltip: '${_groupLabel(p['group'].toString())} • ${p['email']}',
                  onDeleted: () => setState(() => _persons
                      .removeWhere((s) => s['user_id'] == p['user_id'])),
                ),
              if (_persons.length > 1)
                ActionChip(
                  avatar: const Icon(Icons.clear_all, size: 18),
                  label: const Text('إزالة الكل'),
                  onPressed: () => setState(() => _persons.clear()),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _personSearch() {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _searchCtrl,
      focusNode: _searchFocus,
      displayStringForOption: (p) => p['name'].toString(),
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable.empty();
        return _people.where((p) =>
            !_isPicked(p) &&
            (p['name'].toString().toLowerCase().contains(q) ||
                p['email'].toString().contains(q)));
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final p in options)
                  ListTile(
                    dense: true,
                    title: Text(p['name'].toString()),
                    subtitle: Text(_groupLabel(p['group'].toString())),
                    onTap: () => onSelected(p),
                  ),
              ],
            ),
          ),
        ),
      ),
      onSelected: (p) {
        setState(() => _persons.add(p));
        // تفريغ البحث لاختيار شخص آخر مباشرة
        WidgetsBinding.instance.addPostFrameCallback((_) => _searchCtrl.clear());
      },
      fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
        controller: ctrl,
        focusNode: focus,
        decoration: const InputDecoration(
          hintText: 'ابحث بالاسم أو الإيميل وأضف من تريد',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراسلة بالبريد'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'سجل الرسائل',
            onPressed: _loading ? null : _openHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Text(
                        'من: $_from  •  أُرسل خلال 24 ساعة: $_sentLast24h من $_dailyLimit',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'طريقة الإرسال',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<_Mode>(
                              segments: [
                                for (final m in _Mode.values)
                                  ButtonSegment(value: m, label: Text(m.label)),
                              ],
                              selected: {_mode},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) =>
                                  setState(() => _mode = s.first),
                            ),
                            const SizedBox(height: 6),
                            Text(_mode.hint,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      if (_mode == _Mode.single)
                        _section('المستلمون (${_persons.length})', _personPicker())
                      else
                        _section(
                          'المستلمون ($_recipientCount)',
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final g in _groups)
                                  CheckboxListTile(
                                    dense: true,
                                    activeColor: _kColor,
                                    value: _selectedGroups.contains(g['key']),
                                    title: Text(g['label'].toString()),
                                    secondary: Text('${g['count']}'),
                                    onChanged: (g['count'] as num) == 0
                                        ? null
                                        : (v) => setState(() => v == true
                                            ? _selectedGroups
                                                .add(g['key'].toString())
                                            : _selectedGroups
                                                .remove(g['key'].toString())),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      _section(
                        'الرسالة',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _subjectCtrl,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                labelText: 'العنوان',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: _kColor,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _greeting,
                              onChanged: (v) =>
                                  setState(() => _greeting = v ?? true),
                              title: const Text('إضافة التحية في أول الرسالة'),
                              subtitle: _greeting
                                  ? Text(
                                      _mode == _Mode.bcc
                                          ? _kSalam
                                          : 'الشيخ الفاضل / الشيخة الفاضلة (حسب المستلم) + الاسم\n$_kSalam',
                                      style: const TextStyle(
                                          color: Colors.black54, height: 1.6),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _bodyCtrl,
                              minLines: 10,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText: 'اكتب الرسالة هنا أو الصقها…',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.content_paste, size: 18),
                                  label: const Text('لصق'),
                                  onPressed: _paste,
                                ),
                                if (_mode != _Mode.bcc)
                                  ActionChip(
                                    avatar: const Icon(Icons.person_add_alt, size: 18),
                                    label: const Text('إدراج الاسم'),
                                    onPressed: () => _insertAtCursor(_kName),
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.clear, size: 18),
                                  label: const Text('مسح'),
                                  onPressed: () => _bodyCtrl.clear(),
                                ),
                              ],
                            ),
                            if (_mode != _Mode.bcc)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  '{الاسم} يُستبدل باسم كل مستلم، مثل: السلام عليكم {الاسم}،',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _preview,
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('معاينة'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testing ? null : _sendTest,
                              icon: _testing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.science_outlined),
                              label: const Text('تجربة على بريدي'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: _kColor,
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: _testing ? null : _send,
                        icon: const Icon(Icons.send),
                        label: Text(_recipientCount > 0
                            ? 'إرسال إلى $_recipientCount'
                            : 'إرسال'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '"تجربة على بريدي" ترسل نسخة واحدة إلى بريد حسابك فقط، كما ستصل لأول مستلم.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
    );
  }
}
