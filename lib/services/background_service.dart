import 'dart:io';
import 'package:flutter/services.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._();
  factory BackgroundService() => _instance;
  BackgroundService._();

  static const MethodChannel _channel = MethodChannel('com.star.FileW2M/service');
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<bool> startService() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('startService');
      _isRunning = true;
      return result ?? true;
    } catch (e) {
      print('Failed to start service: $e');
      return false;
    }
  }

  Future<bool> stopService() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod('stopService');
      _isRunning = false;
      return result ?? true;
    } catch (e) {
      print('Failed to stop service: $e');
      return false;
    }
  }
}
