import 'package:flutter/material.dart';

class NotificationNavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final ValueNotifier<int?> studentTabToOpen = ValueNotifier<int?>(null);

  static void openStudentMessages() {
    studentTabToOpen.value = 2;
  }

  static void openStudentSessions() {
    studentTabToOpen.value = 1;
  }

  static void clearStudentTab() {
    studentTabToOpen.value = null;
  }
}