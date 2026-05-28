import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';

class DeviceProvider extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final Map<String, Device> _devices = {};
  final Set<String> _connectedIps = {};
  String? _currentDeviceId;
  String? _currentDeviceName;
  Timer? _cleanupTimer;
  StreamSubscription? _foundSub;
  StreamSubscription? _lostSub;

  Map<String, Device> get devices => Map.unmodifiable(_devices);

  List<Device> get deviceList {
    return _devices.values.where((d) {
      // Connected devices always show
      if (_connectedIps.contains(d.ip)) return true;
      // Other devices only show if online
      return d.isOnline;
    }).toList();
  }

  String? get currentDeviceId => _currentDeviceId;
  String? get currentDeviceName => _currentDeviceName;
  DiscoveryService get discoveryService => _discoveryService;

  void markConnected(String ip) {
    _connectedIps.add(ip);
    notifyListeners();
  }

  void markDisconnected(String ip) {
    _connectedIps.remove(ip);
    notifyListeners();
  }

  bool isDeviceConnected(String ip) => _connectedIps.contains(ip);

  Future<void> startDiscovery(String deviceId, String deviceName) async {
    _currentDeviceId = deviceId;
    _currentDeviceName = deviceName;

    await _discoveryService.start(deviceId, deviceName);

    _foundSub?.cancel();
    _lostSub?.cancel();

    _foundSub = _discoveryService.deviceFound.listen((device) {
      _devices[device.id] = device;
      notifyListeners();
    });

    _lostSub = _discoveryService.deviceLost.listen((deviceId) {
      // Don't remove if device is connected
      final device = _devices[deviceId];
      if (device != null && _connectedIps.contains(device.ip)) return;
      _devices.remove(deviceId);
      notifyListeners();
    });

    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupOfflineDevices(),
    );
  }

  void _cleanupOfflineDevices() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _devices.entries) {
      // Never remove connected devices
      if (_connectedIps.contains(entry.value.ip)) continue;
      // Remove devices offline for more than 30 seconds
      if (now.difference(entry.value.lastSeen).inSeconds > 30) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _devices.remove(id);
      }
      notifyListeners();
    }
  }

  void refresh() {
    // Don't clear connected devices
    _devices.removeWhere((_, d) => !_connectedIps.contains(d.ip));
    _discoveryService.refresh();
    notifyListeners();
  }

  Device? getDeviceById(String id) => _devices[id];

  Device? getDeviceByIp(String ip) {
    try {
      return _devices.values.firstWhere((d) => d.ip == ip);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _foundSub?.cancel();
    _lostSub?.cancel();
    _cleanupTimer?.cancel();
    _discoveryService.stop();
    super.dispose();
  }
}
