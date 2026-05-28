import 'package:flutter/material.dart';

enum DeviceType { android, windows, unknown }

class Device {
  final String id;
  final String name;
  final DeviceType type;
  final String ip;
  final int tcpPort;
  final DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.ip,
    required this.tcpPort,
    required this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json, String ip) {
    return Device(
      id: json['device_id'] ?? '',
      name: json['device_name'] ?? 'Unknown',
      type: _parseDeviceType(json['device_type']),
      ip: ip,
      tcpPort: json['tcp_port'] ?? 52001,
      lastSeen: DateTime.now(),
    );
  }

  static DeviceType _parseDeviceType(String? type) {
    switch (type) {
      case 'android':
        return DeviceType.android;
      case 'windows':
        return DeviceType.windows;
      default:
        return DeviceType.unknown;
    }
  }

  String get typeLabel {
    switch (type) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.windows:
        return 'Windows';
      default:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (type) {
      case DeviceType.android:
        return Icons.phone_android;
      case DeviceType.windows:
        return Icons.computer;
      default:
        return Icons.device_unknown;
    }
  }

  bool get isOnline => DateTime.now().difference(lastSeen).inSeconds < 10;

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    String? ip,
    int? tcpPort,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ip: ip ?? this.ip,
      tcpPort: tcpPort ?? this.tcpPort,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
