import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static String get deviceType {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  static String get deviceTypeName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    return 'Unknown';
  }
}
