import 'package:flutter/material.dart';

class NotificationNavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final ValueNotifier<int?> studentTabToOpen = ValueNotifier<int?>(null);
  static final ValueNotifier<int?> teacherTabToOpen = ValueNotifier<int?>(null);
  static final ValueNotifier<int?> adminTabToOpen   = ValueNotifier<int?>(null);

  static void openStudentMessages() => studentTabToOpen.value = 2;
  static void openStudentSessions() => studentTabToOpen.value = 1;
  static void clearStudentTab()     => studentTabToOpen.value = null;

  static void openTeacherMessages() => teacherTabToOpen.value = 3;
  static void clearTeacherTab()     => teacherTabToOpen.value = null;

  static void openAdminMessages()   => adminTabToOpen.value = 4;
  static void clearAdminTab()       => adminTabToOpen.value = null;
}
