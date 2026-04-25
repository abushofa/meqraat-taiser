import 'package:flutter/widgets.dart';

class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isSmallPhone(BuildContext context) => width(context) < 380;

  static bool isPhone(BuildContext context) => width(context) < 600;

  static bool isTablet(BuildContext context) => width(context) >= 600;

  static double statsCardExtent(BuildContext context) {
    final w = width(context);

    if (w < 380) return 164; // أجهزة أندرويد المتوسطة والصغيرة
    if (w < 430) return 154; // أغلب الهواتف
    return 142; // الهواتف الكبيرة
  }

  static int statsCrossAxisCount(BuildContext context) {
    final w = width(context);

    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  static double pagePadding(BuildContext context) {
    final w = width(context);

    if (w < 380) return 12;
    if (w < 600) return 16;
    return 20;
  }
}