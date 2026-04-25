import 'package:flutter/material.dart';

class AppSnackBar {
  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      color: Colors.green,
      icon: Icons.check_circle,
      seconds: 3,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message,
      color: Colors.red,
      icon: Icons.error,
      seconds: 4,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      color: Colors.blue,
      icon: Icons.info,
      seconds: 3,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message,
      color: Colors.orange,
      icon: Icons.warning_amber_rounded,
      seconds: 4,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
    required int seconds,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final text = message.trim().isEmpty ? 'تمت العملية' : message;

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 6,
        duration: Duration(seconds: seconds),
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        dismissDirection: DismissDirection.horizontal,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}