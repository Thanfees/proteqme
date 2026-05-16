import 'dart:io';

class PlatformUtils {
  const PlatformUtils._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIos => Platform.isIOS;
}
