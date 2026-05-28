import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  String _deviceName = '';
  String _deviceId = '';
  String _savePath = '';
  bool _autoAccept = false;
  bool _notifyOnComplete = true;
  bool _backgroundService = false;

  String get deviceName => _deviceName;
  String get deviceId => _deviceId;
  String get savePath => _savePath;
  bool get autoAccept => _autoAccept;
  bool get notifyOnComplete => _notifyOnComplete;
  bool get backgroundService => _backgroundService;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs.getString('device_id') ?? const Uuid().v4();
    _deviceName = _prefs.getString('device_name') ?? _getDefaultDeviceName();
    _savePath = _prefs.getString('save_path') ?? '';
    _autoAccept = _prefs.getBool('auto_accept') ?? false;
    _notifyOnComplete = _prefs.getBool('notify_on_complete') ?? true;
    _backgroundService = _prefs.getBool('background_service') ?? false;

    // Set default save path if not configured
    if (_savePath.isEmpty) {
      _savePath = await _getDefaultSavePath();
      await _prefs.setString('save_path', _savePath);
    }

    await _prefs.setString('device_id', _deviceId);
  }

  String _getDefaultDeviceName() {
    return 'Device-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<String> _getDefaultSavePath() async {
    try {
      if (Platform.isWindows) {
        // Use Downloads folder on Windows
        final home = Platform.environment['USERPROFILE'] ?? '';
        if (home.isNotEmpty) {
          final downloads = '$home${Platform.pathSeparator}Downloads${Platform.pathSeparator}FileTransfer';
          return downloads;
        }
      }
      // Fallback: use app documents directory
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}${Platform.pathSeparator}FileTransfer';
    } catch (e) {
      return '${Directory.current.path}${Platform.pathSeparator}received';
    }
  }

  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    await _prefs.setString('device_name', name);
    notifyListeners();
  }

  Future<void> setSavePath(String path) async {
    _savePath = path;
    await _prefs.setString('save_path', path);
    notifyListeners();
  }

  Future<void> setAutoAccept(bool value) async {
    _autoAccept = value;
    await _prefs.setBool('auto_accept', value);
    notifyListeners();
  }

  Future<void> setNotifyOnComplete(bool value) async {
    _notifyOnComplete = value;
    await _prefs.setBool('notify_on_complete', value);
    notifyListeners();
  }

  Future<void> setBackgroundService(bool value) async {
    _backgroundService = value;
    await _prefs.setBool('background_service', value);
    notifyListeners();
  }
}
