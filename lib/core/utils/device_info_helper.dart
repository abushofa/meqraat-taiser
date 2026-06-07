import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  /// اسم الجهاز المقروء للعرض (قابل للتغيير من المستخدم)
  static Future<String> getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.name.isNotEmpty ? ios.name : ios.utsname.machine;
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand;
        final model = android.model;
        if (model.toLowerCase().startsWith(brand.toLowerCase())) {
          return model;
        }
        return '$brand $model';
      }
    } catch (_) {}
    return 'جهاز غير معروف';
  }

  /// معرّف ثابت للجهاز — لا يتغير حتى لو غيّر المستخدم اسم الجهاز
  /// iOS: identifierForVendor | Android: androidId
  static Future<String> getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? ios.utsname.machine;
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      }
    } catch (_) {}
    return '';
  }
}
