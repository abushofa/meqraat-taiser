import 'package:flutter/material.dart';
import '../utils/app_labels.dart';

class StatusBadge extends StatelessWidget {
  final String? status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  Color _bgColor(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'approved':
      case 'ended':
      case 'present':
        return Colors.green.shade100;
      case 'pending':
      case 'started':
        return Colors.orange.shade100;
      case 'rejected':
      case 'cancelled':
      case 'absent':
        return Colors.red.shade100;
      case 'waitlisted':
        return Colors.amber.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _textColor(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'approved':
      case 'ended':
      case 'present':
        return Colors.green.shade800;
      case 'pending':
      case 'started':
        return Colors.orange.shade800;
      case 'rejected':
      case 'cancelled':
      case 'absent':
        return Colors.red.shade800;
      case 'waitlisted':
        return Colors.amber.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor(status),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        AppLabels.status(status),
        style: TextStyle(
          color: _textColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}