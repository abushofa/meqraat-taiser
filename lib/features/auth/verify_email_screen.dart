import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final int userId;
  final String email;
  final String name;

  const VerifyEmailScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.name,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _successMsg;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'أدخل الكود المكون من 6 أرقام');
      return;
    }

    setState(() { _loading = true; _error = null; _successMsg = null; });

    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post('/verify_email.php', data: {
        'action': 'verify',
        'user_id': widget.userId,
        'code': code,
      });
      final body = res.data;
      if (body is Map && body['ok'] == true) {
        setState(() => _successMsg = body['message']?.toString() ?? 'تم التحقق بنجاح.');
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() => _error = (body is Map ? body['message'] : null)?.toString() ?? 'فشل التحقق.');
      }
    } on DioException catch (e) {
      setState(() => _error = (e.response?.data is Map ? e.response?.data['message'] : null)?.toString() ?? 'فشل الاتصال بالخادم.');
    } catch (_) {
      setState(() => _error = 'حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; _successMsg = null; });
    try {
      final dio = await ApiClient.getInstance();
      final res = await dio.post('/verify_email.php', data: {
        'action': 'resend',
        'user_id': widget.userId,
        'email': widget.email,
        'name': widget.name,
      });
      final body = res.data;
      setState(() {
        if (body is Map && body['ok'] == true) {
          _successMsg = 'تم إرسال كود جديد. راجع صندوق الوارد والـ Spam.';
        } else {
          _error = (body is Map ? body['message'] : null)?.toString() ?? 'فشل إعادة الإرسال.';
        }
      });
    } catch (_) {
      setState(() => _error = 'فشل الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من البريد الإلكتروني'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 56, color: Colors.teal),
                    const SizedBox(height: 16),
                    const Text(
                      'تحقق من بريدك الإلكتروني',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أرسلنا كود التحقق إلى:\n${widget.email}\n\nإذا لم تجده في صندوق الوارد، راجع مجلد Spam.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
                      decoration: const InputDecoration(
                        labelText: 'كود التحقق',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),

                    if (_successMsg != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(_successMsg!, style: TextStyle(color: Colors.green.shade700)),
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('تحقق'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resending ? null : _resend,
                      child: _resending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('لم يصلني الكود — أعد الإرسال'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
