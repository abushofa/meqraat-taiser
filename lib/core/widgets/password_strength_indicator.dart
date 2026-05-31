import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  bool get _hasLength => password.length >= 8;
  bool get _hasUpper  => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLower  => password.contains(RegExp(r'[a-z]'));
  bool get _hasDigit  => password.contains(RegExp(r'[0-9]'));

  int get _score => [_hasLength, _hasUpper, _hasLower, _hasDigit].where((v) => v).length;

  Color get _barColor {
    switch (_score) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.yellow.shade700;
      case 4: return Colors.green;
      default: return Colors.grey.shade300;
    }
  }

  String get _label {
    switch (_score) {
      case 1: return 'ضعيفة جداً';
      case 2: return 'ضعيفة';
      case 3: return 'متوسطة';
      case 4: return 'قوية';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // شريط القوة
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(left: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i < _score ? _barColor : Colors.grey.shade200,
                ),
              ),
            );
          }),
        ),
        if (_label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'قوة كلمة المرور: $_label',
            style: TextStyle(fontSize: 12, color: _barColor, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 6),
        // شروط القوة
        _criterion('8 أحرف على الأقل',        _hasLength),
        _criterion('حرف كبير (A-Z)',           _hasUpper),
        _criterion('حرف صغير (a-z)',           _hasLower),
        _criterion('رقم (0-9)',                _hasDigit),
      ],
    );
  }

  Widget _criterion(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: met ? Colors.green : Colors.grey)),
        ],
      ),
    );
  }
}
