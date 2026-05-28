import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class ConnectionService {
  ServerSocket? _server;
  final Map<String, Socket> _connections = {};
  final Map<String, List<int>> _buffers = {};
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<String> _connectionLostController = StreamController.broadcast();
  final StreamController<String> _connectionEstablishedController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _connectionRequestController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<String> get connectionLost => _connectionLostController.stream;
  Stream<String> get connectionEstablished => _connectionEstablishedController.stream;
  Stream<Map<String, dynamic>> get connectionRequests => _connectionRequestController.stream;
  Map<String, Socket> get connections => Map.unmodifiable(_connections);
  bool isConnected(String ip) => _connections.containsKey(ip);

  Future<void> startServer() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, AppConstants.tcpPort);
    _server!.listen(_onNewConnection);
  }

  void _onNewConnection(Socket socket) {
    final address = socket.remoteAddress.address;
    debugPrint('New connection from $address');
    _connections[address] = socket;
    _buffers[address] = [];

    socket.listen(
      (data) => _onData(address, data),
      onDone: () => _onDisconnected(address),
      onError: (e) => _onError(address, e),
    );
  }

  /// Send a connection request. Returns a Future that completes when approved/denied.
  Future<bool> requestConnection(String ip, String deviceName, {String? deviceId, String? deviceType}) async {
    final completer = Completer<bool>();

    // Listen for response
    late StreamSubscription sub;
    sub = messages.listen((message) {
      if (message['_source_ip'] == ip && message['type'] == 'connection_response') {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete(message['approved'] == true);
        }
      }
    });

    // Send request
    final socket = await Socket.connect(ip, AppConstants.tcpPort);
    _connections[ip] = socket;
    _buffers[ip] = [];

    socket.listen(
      (data) => _onData(ip, data),
      onDone: () => _onDisconnected(ip),
      onError: (e) => _onError(ip, e),
    );

    await sendMessage(ip, {
      'type': 'connection_request',
      'device_name': deviceName,
      'device_id': deviceId,
      'device_type': deviceType,
    });

    // Timeout after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Approve a connection request
  Future<void> approveConnection(String ip, {String? deviceId, String? deviceName, String? deviceType}) async {
    await sendMessage(ip, {
      'type': 'connection_response',
      'approved': true,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType,
    });
    _connectionEstablishedController.add(ip);
  }

  /// Deny a connection request
  Future<void> denyConnection(String ip) async {
    await sendMessage(ip, {
      'type': 'connection_response',
      'approved': false,
    });
    await closeConnection(ip);
  }

  Future<Socket> connect(String ip) async {
    if (_connections.containsKey(ip)) {
      return _connections[ip]!;
    }

    final socket = await Socket.connect(ip, AppConstants.tcpPort);
    _connections[ip] = socket;
    _buffers[ip] = [];
    _connectionEstablishedController.add(ip);

    socket.listen(
      (data) => _onData(ip, data),
      onDone: () => _onDisconnected(ip),
      onError: (e) => _onError(ip, e),
    );

    return socket;
  }

  void _onData(String ip, Uint8List data) {
    final buffer = _buffers[ip];
    if (buffer == null) return;

    buffer.addAll(data);
    _processBuffer(ip);
  }

  void _processBuffer(String ip) {
    final buffer = _buffers[ip];
    if (buffer == null) return;

    while (buffer.length >= 4) {
      final length = ByteData.sublistView(Uint8List.fromList(buffer.sublist(0, 4)))
          .getInt32(0, Endian.big);

      if (length <= 0 || length > 100 * 1024 * 1024) {
        buffer.clear();
        return;
      }

      if (buffer.length < 4 + length) return;

      final messageBytes = buffer.sublist(4, 4 + length);
      buffer.removeRange(0, 4 + length);

      try {
        final message = utf8.decode(messageBytes);
        final json = jsonDecode(message) as Map<String, dynamic>;
        json['_source_ip'] = ip;

        // Handle different message types
        if (json['type'] == 'connection_request') {
          _connectionRequestController.add(json);
        } else if (json['type'] == 'connection_response') {
          // Response is handled by the completer in requestConnection
          _messageController.add(json);
        } else if (json['type'] == 'disconnect') {
          // Handle disconnect message
          _onDisconnected(ip);
        } else {
          _messageController.add(json);
        }
      } catch (e) {
        debugPrint('Message parse error from $ip: $e');
      }
    }
  }

  void _onDisconnected(String ip) {
    final socket = _connections.remove(ip);
    _buffers.remove(ip);
    _connectionLostController.add(ip);
    debugPrint('Disconnected from $ip');

    // Close socket if it's still open
    socket?.close().catchError((_) {});
  }

  void _onError(String ip, dynamic error) {
    debugPrint('Connection error from $ip: $error');
    _connections.remove(ip);
    _buffers.remove(ip);
    _connectionLostController.add(ip);
  }

  Future<void> sendMessage(String ip, Map<String, dynamic> message) async {
    Socket? socket = _connections[ip];
    socket ??= await connect(ip);

    final data = utf8.encode(jsonEncode(message));
    final length = ByteData(4)..setInt32(0, data.length, Endian.big);
    socket.add(length.buffer.asUint8List());
    socket.add(data);
    await socket.flush();
  }

  Future<void> sendFileChunk(String ip, String taskId, Uint8List chunkData) async {
    Socket? socket = _connections[ip];
    socket ??= await connect(ip);

    final message = {
      'type': 'file_chunk',
      'task_id': taskId,
      'data': base64Encode(chunkData),
    };
    final data = utf8.encode(jsonEncode(message));
    final length = ByteData(4)..setInt32(0, data.length, Endian.big);
    socket.add(length.buffer.asUint8List());
    socket.add(data);
    await socket.flush();
  }

  Future<void> closeConnection(String ip) async {
    // Send disconnect message before closing
    final socket = _connections[ip];
    if (socket != null) {
      try {
        final data = utf8.encode(jsonEncode({'type': 'disconnect'}));
        final length = ByteData(4)..setInt32(0, data.length, Endian.big);
        socket.add(length.buffer.asUint8List());
        socket.add(data);
        await socket.flush();
      } catch (_) {}
    }

    _connections.remove(ip);
    _buffers.remove(ip);
    await socket?.close();
  }

  Future<void> stop() async {
    for (final socket in _connections.values) {
      await socket.close();
    }
    _connections.clear();
    _buffers.clear();
    await _server?.close();
    _server = null;
    await _messageController.close();
    await _connectionLostController.close();
    await _connectionEstablishedController.close();
    await _connectionRequestController.close();
  }
}
