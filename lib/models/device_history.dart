class DeviceHistory {
  final String id;
  final String name;
  final String ip;
  final String type; // 'android' or 'windows'
  final DateTime lastConnected;
  final int connectionCount;

  DeviceHistory({
    required this.id,
    required this.name,
    required this.ip,
    required this.type,
    required this.lastConnected,
    this.connectionCount = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'type': type,
      'lastConnected': lastConnected.millisecondsSinceEpoch,
      'connectionCount': connectionCount,
    };
  }

  factory DeviceHistory.fromJson(Map<String, dynamic> json) {
    return DeviceHistory(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      ip: json['ip'] ?? '',
      type: json['type'] ?? 'unknown',
      lastConnected: DateTime.fromMillisecondsSinceEpoch(json['lastConnected'] ?? 0),
      connectionCount: json['connectionCount'] ?? 1,
    );
  }

  DeviceHistory copyWith({
    String? id,
    String? name,
    String? ip,
    String? type,
    DateTime? lastConnected,
    int? connectionCount,
  }) {
    return DeviceHistory(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      type: type ?? this.type,
      lastConnected: lastConnected ?? this.lastConnected,
      connectionCount: connectionCount ?? this.connectionCount,
    );
  }
}
