import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_transfer.dart';
import '../services/file_service.dart';
import '../services/connection_service.dart';
import '../services/notification_service.dart';

class TransferProvider extends ChangeNotifier {
  late final ConnectionService _connectionService;
  late final FileService _fileService;
  final NotificationService _notificationService = NotificationService();
  final List<FileTransferTask> _tasks = [];
  final Set<String> _connectedPeers = {};
  final Map<String, Map<String, dynamic>> _pendingConnectionRequests = {};
  StreamSubscription? _taskSubscription;
  StreamSubscription? _requestSubscription;
  StreamSubscription? _connectionLostSubscription;
  StreamSubscription? _connectionEstablishedSubscription;
  StreamSubscription? _connectionRequestSubscription;
  bool _autoAcceptConnections = false;

  List<FileTransferTask> get tasks => List.unmodifiable(_tasks);
  Set<String> get connectedPeers => Set.unmodifiable(_connectedPeers);
  FileService get fileService => _fileService;
  ConnectionService get connectionService => _connectionService;
  bool get autoAcceptConnections => _autoAcceptConnections;

  // Callback for when a device connects (for saving to history)
  Function(String deviceId, String deviceName, String ip, String deviceType)? onDeviceConnected;

  TransferProvider() {
    _connectionService = ConnectionService();
    _fileService = FileService(_connectionService);
  }

  Future<void> init() async {
    await _connectionService.startServer();
    _fileService.init();
    await _notificationService.init();

    // Load persisted tasks
    await _loadTasks();
    await _loadSettings();

    _taskSubscription = _fileService.taskUpdates.listen((task) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _tasks[index] = task;
      } else {
        _tasks.add(task);
      }
      _saveTasks();
      notifyListeners();
    });

    _requestSubscription = _fileService.incomingRequests.listen((task) {
      _tasks.add(task);
      _saveTasks();
      notifyListeners();

      // Show notification for incoming file
      _notificationService.showFileNotification(
        title: '收到文件',
        body: '${task.peerDeviceName} 发送了 ${task.fileName} (${task.sizeLabel})',
      );
    });

    _connectionLostSubscription = _connectionService.connectionLost.listen((ip) {
      _connectedPeers.remove(ip);
      notifyListeners();
    });

    _connectionEstablishedSubscription = _connectionService.connectionEstablished.listen((ip) {
      _connectedPeers.add(ip);
      notifyListeners();
    });

    // Listen for incoming connection requests
    _connectionRequestSubscription = _connectionService.connectionRequests.listen((request) {
      final ip = request['_source_ip'] as String;
      final deviceName = request['device_name'] as String? ?? ip;
      final deviceId = request['device_id'] as String?;
      final deviceType = request['device_type'] as String?;

      // Store device info for later use
      _pendingConnectionRequests[ip] = {
        'device_name': deviceName,
        'device_id': deviceId,
        'device_type': deviceType,
      };

      if (_autoAcceptConnections) {
        approveConnection(ip);
      } else {
        // Show notification
        _notificationService.showConnectionRequestNotification(deviceName: deviceName);
        // The UI will handle showing the dialog
      }
    });
  }

  bool isConnected(String ip) => _connectedPeers.contains(ip);

  Future<bool> connectToDevice(String ip, String deviceName, {String? deviceId, String? deviceType}) async {
    try {
      // Send connection request and wait for approval
      final approved = await _connectionService.requestConnection(
        ip,
        deviceName,
        deviceId: deviceId,
        deviceType: deviceType,
      );
      if (approved) {
        _connectedPeers.add(ip);
        notifyListeners();
      }
      return approved;
    } catch (e) {
      debugPrint('Connect failed: $e');
      return false;
    }
  }

  Future<void> approveConnection(String ip, {String? deviceId, String? deviceName, String? deviceType}) async {
    // Get pending request info
    final pendingInfo = _pendingConnectionRequests.remove(ip);

    // Use provided info or fallback to pending request info
    final finalDeviceId = deviceId ?? pendingInfo?['device_id'] ?? ip;
    final finalDeviceName = deviceName ?? pendingInfo?['device_name'] ?? ip;
    final finalDeviceType = deviceType ?? pendingInfo?['device_type'] ?? 'unknown';

    await _connectionService.approveConnection(
      ip,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
    );
    _connectedPeers.add(ip);
    notifyListeners();

    // Notify about connected device for saving to history
    if (onDeviceConnected != null) {
      onDeviceConnected!(finalDeviceId, finalDeviceName, ip, finalDeviceType);
    }
  }

  Future<void> denyConnection(String ip) async {
    await _connectionService.denyConnection(ip);
  }

  Future<void> disconnectFromDevice(String ip) async {
    await _connectionService.closeConnection(ip);
    _connectedPeers.remove(ip);
    notifyListeners();
  }

  Future<void> sendFiles(List<String> filePaths, String peerIp, String peerDeviceId, String peerDeviceName) async {
    await _fileService.sendFiles(filePaths, peerIp, peerDeviceId, peerDeviceName);
  }

  Future<void> acceptFile(String taskId, String savePath) async {
    await _fileService.acceptFile(taskId, savePath);
  }

  Future<void> rejectFile(String taskId) async {
    await _fileService.rejectFile(taskId);
  }

  Future<void> deleteTaskAndFile(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final task = _tasks[index];

    // Delete file if it exists and was received
    if (task.filePath != null && task.direction == TransferDirection.receive) {
      try {
        final file = File(task.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Delete file failed: $e');
      }
    }

    _tasks.removeAt(index);
    _saveTasks();
    notifyListeners();
  }

  List<FileTransferTask> getTasksForPeer(String peerId) {
    return _tasks.where((t) => t.peerDeviceId == peerId).toList();
  }

  void setAutoAcceptConnections(bool value) {
    _autoAcceptConnections = value;
    _saveSettings();
    notifyListeners();
  }

  // Persistence
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskList = _tasks.map((t) => {
        'id': t.id,
        'fileName': t.fileName,
        'fileSize': t.fileSize,
        'filePath': t.filePath,
        'sha256': t.sha256,
        'peerDeviceId': t.peerDeviceId,
        'peerDeviceName': t.peerDeviceName,
        'direction': t.direction.index,
        'status': t.status.index,
        'transferredBytes': t.transferredBytes,
        'startTime': t.startTime.millisecondsSinceEpoch,
        'errorMessage': t.errorMessage,
      }).toList();
      await prefs.setString('transfer_tasks', jsonEncode(taskList));
    } catch (e) {
      debugPrint('Save tasks failed: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('transfer_tasks');
      if (data == null) return;

      final taskList = jsonDecode(data) as List;
      for (final json in taskList) {
        _tasks.add(FileTransferTask(
          id: json['id'],
          fileName: json['fileName'],
          fileSize: json['fileSize'],
          filePath: json['filePath'],
          sha256: json['sha256'],
          peerDeviceId: json['peerDeviceId'],
          peerDeviceName: json['peerDeviceName'],
          direction: TransferDirection.values[json['direction']],
          status: TransferStatus.values[json['status']],
          transferredBytes: json['transferredBytes'],
          startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
          errorMessage: json['errorMessage'],
        ));
      }
    } catch (e) {
      debugPrint('Load tasks failed: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_accept_connections', _autoAcceptConnections);
    } catch (e) {
      debugPrint('Save settings failed: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoAcceptConnections = prefs.getBool('auto_accept_connections') ?? false;
    } catch (e) {
      debugPrint('Load settings failed: $e');
    }
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    _requestSubscription?.cancel();
    _connectionLostSubscription?.cancel();
    _connectionEstablishedSubscription?.cancel();
    _connectionRequestSubscription?.cancel();
    _fileService.dispose();
    _connectionService.stop();
    super.dispose();
  }
}
