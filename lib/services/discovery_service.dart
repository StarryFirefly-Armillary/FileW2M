import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';

class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  String? _deviceId;
  String? _deviceName;
  final Map<String, Device> _devices = {};
  final StreamController<Device> _deviceFoundController = StreamController.broadcast();
  final StreamController<String> _deviceLostController = StreamController.broadcast();

  Stream<Device> get deviceFound => _deviceFoundController.stream;
  Stream<String> get deviceLost => _deviceLostController.stream;
  Map<String, Device> get devices => Map.unmodifiable(_devices);

  Future<void> start(String deviceId, String deviceName) async {
    _deviceId = deviceId;
    _deviceName = deviceName;

    print('DiscoveryService.start: deviceId=$deviceId, deviceName=$deviceName');

    // Stop existing socket first
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;

    try {
      // Try to bind to the discovery port
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;

      print('DiscoveryService: Socket bound to port ${AppConstants.discoveryPort}');

      _socket!.listen(
        _onData,
        onError: (e) {
          print('Discovery socket error: $e');
          _socket = null;
        },
        onDone: () {
          print('Discovery socket closed');
          _socket = null;
        },
      );

      // Broadcast immediately
      _broadcast();

      // Then broadcast periodically
      _broadcastTimer = Timer.periodic(
        const Duration(seconds: AppConstants.broadcastIntervalSeconds),
        (_) => _broadcast(),
      );

      print('Discovery started on port ${AppConstants.discoveryPort}');
    } catch (e) {
      print('Discovery start failed: $e');
      _socket = null;

      // Try alternative port if the main port is busy
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0, // Let OS assign a port
          reuseAddress: true,
        );
        _socket!.broadcastEnabled = true;

        print('DiscoveryService: Socket bound to alternative port ${_socket!.port}');

        _socket!.listen(
          _onData,
          onError: (e) {
            print('Discovery socket error: $e');
            _socket = null;
          },
          onDone: () {
            print('Discovery socket closed');
            _socket = null;
          },
        );

        _broadcast();
        _broadcastTimer = Timer.periodic(
          const Duration(seconds: AppConstants.broadcastIntervalSeconds),
          (_) => _broadcast(),
        );
      } catch (e2) {
        print('Discovery start failed on alternative port: $e2');
        _socket = null;
      }
    }
  }

  void refresh() {
    _devices.clear();
    _broadcast();
  }

  void _onData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    print('Discovery: Received data from ${datagram.address.address}:${datagram.port}');

    try {
      final message = utf8.decode(datagram.data);
      print('Discovery: Message: $message');
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['type'] == 'discover' && json['device_id'] != _deviceId) {
        final ip = datagram.address.address;
        final device = Device.fromJson(json, ip);

        print('Discovery: Found device ${device.name} at $ip');

        final isNew = !_devices.containsKey(device.id);
        _devices[device.id] = device.copyWith(lastSeen: DateTime.now());

        if (isNew) {
          _deviceFoundController.add(_devices[device.id]!);
        }
      } else if (json['type'] == 'discover' && json['device_id'] == _deviceId) {
        print('Discovery: Ignoring own broadcast');
      } else {
        print('Discovery: Ignoring message (type=${json['type']}, device_id=${json['device_id']})');
      }
    } catch (e) {
      print('Discovery parse error: $e');
    }
  }

  Future<void> _broadcast() async {
    if (_socket == null) {
      print('Discovery: Socket is null, cannot broadcast');
      return;
    }

    try {
      final message = jsonEncode({
        'type': 'discover',
        'device_id': _deviceId,
        'device_name': _deviceName,
        'device_type': PlatformUtils.deviceType,
        'tcp_port': AppConstants.tcpPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final data = utf8.encode(message);

      // Try multiple broadcast addresses
      final addresses = [
        InternetAddress('255.255.255.255'),
      ];

      // Add local subnet broadcast if available
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            // Calculate broadcast address for the subnet
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final broadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              if (!addresses.any((a) => a.address == broadcast)) {
                addresses.add(InternetAddress(broadcast));
              }
            }
          }
        }
      } catch (e) {
        print('Discovery: Error getting network interfaces: $e');
      }

      for (final address in addresses) {
        try {
          final sent = _socket!.send(
            data,
            address,
            AppConstants.discoveryPort,
          );
          print('Discovery: Broadcast sent ($sent bytes) to ${address.address}:${AppConstants.discoveryPort}');
        } catch (e) {
          print('Discovery: Failed to send to ${address.address}: $e');
        }
      }
    } catch (e) {
      print('Broadcast error: $e');
    }
  }

  void removeOfflineDevices() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _devices.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds > AppConstants.offlineTimeoutSeconds) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _devices.remove(id);
      _deviceLostController.add(id);
    }
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }
}
