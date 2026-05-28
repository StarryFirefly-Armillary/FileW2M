import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_history.dart';

class DeviceHistoryProvider extends ChangeNotifier {
  final List<DeviceHistory> _history = [];
  static const String _storageKey = 'device_history';
  static const int _maxHistorySize = 50;

  List<DeviceHistory> get history => List.unmodifiable(_history);

  List<DeviceHistory> get sortedHistory {
    final sorted = List<DeviceHistory>.from(_history);
    sorted.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    return sorted;
  }

  Future<void> init() async {
    await _loadHistory();
  }

  Future<void> addOrUpdateDevice(String id, String name, String ip, String type) async {
    final existingIndex = _history.indexWhere((d) => d.id == id || d.ip == ip);

    if (existingIndex >= 0) {
      final existing = _history[existingIndex];
      _history[existingIndex] = existing.copyWith(
        name: name,
        ip: ip,
        type: type,
        lastConnected: DateTime.now(),
        connectionCount: existing.connectionCount + 1,
      );
    } else {
      _history.insert(
        0,
        DeviceHistory(
          id: id,
          name: name,
          ip: ip,
          type: type,
          lastConnected: DateTime.now(),
        ),
      );

      // Limit history size
      if (_history.length > _maxHistorySize) {
        _history.removeRange(_maxHistorySize, _history.length);
      }
    }

    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    _history.removeWhere((d) => d.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  DeviceHistory? getDeviceById(String id) {
    try {
      return _history.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  DeviceHistory? getDeviceByIp(String ip) {
    try {
      return _history.firstWhere((d) => d.ip == ip);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data == null) return;

      final list = jsonDecode(data) as List;
      _history.clear();
      for (final json in list) {
        _history.add(DeviceHistory.fromJson(json));
      }
    } catch (e) {
      debugPrint('Load device history failed: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((d) => d.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Save device history failed: $e');
    }
  }
}
