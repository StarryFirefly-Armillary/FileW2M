import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/file_transfer.dart';
import '../utils/constants.dart';
import '../utils/crypto_utils.dart';
import 'connection_service.dart';

class FileService {
  final ConnectionService _connectionService;
  final Map<String, FileTransferTask> _tasks = {};
  final StreamController<FileTransferTask> _taskUpdateController = StreamController.broadcast();
  final StreamController<FileTransferTask> _incomingRequestController = StreamController.broadcast();

  Stream<FileTransferTask> get taskUpdates => _taskUpdateController.stream;
  Stream<FileTransferTask> get incomingRequests => _incomingRequestController.stream;
  Map<String, FileTransferTask> get tasks => Map.unmodifiable(_tasks);

  FileService(this._connectionService);

  void init() {
    _connectionService.messages.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final sourceIp = message['_source_ip'] as String;

    switch (type) {
      case 'file_request':
        _handleFileRequest(message, sourceIp);
        break;
      case 'file_accept':
        _handleFileAccept(message, sourceIp);
        break;
      case 'file_reject':
        _handleFileReject(message, sourceIp);
        break;
      case 'file_chunk':
        _handleFileChunk(message, sourceIp);
        break;
      case 'file_complete':
        _handleFileComplete(message, sourceIp);
        break;
      case 'file_verified':
        _handleFileVerified(message, sourceIp);
        break;
      case 'file_failed':
        _handleFileFailed(message, sourceIp);
        break;
    }
  }

  Future<void> sendFiles(List<String> filePaths, String peerIp, String peerDeviceId, String peerDeviceName) async {
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) continue;

      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();
      final sha256 = await CryptoUtils.computeFileSha256(filePath);

      final task = FileTransferTask(
        id: '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}',
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        sha256: sha256,
        peerDeviceId: peerIp,
        peerDeviceName: peerDeviceName,
        direction: TransferDirection.send,
      );

      _tasks[task.id] = task;
      _taskUpdateController.add(task);

      await _connectionService.sendMessage(peerIp, {
        'type': 'file_request',
        'task_id': task.id,
        'file_name': fileName,
        'file_size': fileSize,
        'sha256': sha256,
      });
    }
  }

  void _handleFileRequest(Map<String, dynamic> message, String sourceIp) {
    final task = FileTransferTask(
      id: message['task_id'],
      fileName: message['file_name'],
      fileSize: message['file_size'],
      sha256: message['sha256'],
      peerDeviceId: sourceIp,
      peerDeviceName: message['peer_device_name'] ?? sourceIp,
      direction: TransferDirection.receive,
    );

    _tasks[task.id] = task;
    _incomingRequestController.add(task);
  }

  Future<void> acceptFile(String taskId, String savePath) async {
    final task = _tasks[taskId];
    if (task == null) return;

    // Ensure save directory exists
    final dir = Directory(savePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filePath = '$savePath${Platform.pathSeparator}${task.fileName}';
    task.filePath = filePath;
    task.status = TransferStatus.transferring;
    task.transferredBytes = 0;
    _taskUpdateController.add(task);

    // Create empty file
    File(filePath).writeAsBytesSync([]);

    await _connectionService.sendMessage(task.peerDeviceId, {
      'type': 'file_accept',
      'task_id': taskId,
    });
  }

  Future<void> rejectFile(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    task.status = TransferStatus.cancelled;
    _taskUpdateController.add(task);

    await _connectionService.sendMessage(task.peerDeviceId, {
      'type': 'file_reject',
      'task_id': taskId,
    });
  }

  void _handleFileAccept(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null || task.filePath == null) return;

    task.status = TransferStatus.transferring;
    _taskUpdateController.add(task);

    _startSending(task, sourceIp);
  }

  void _handleFileReject(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null) return;

    task.status = TransferStatus.cancelled;
    task.errorMessage = '对方拒绝接收';
    _taskUpdateController.add(task);
  }

  Future<void> _startSending(FileTransferTask task, String peerIp) async {
    try {
      final file = File(task.filePath!);
      final stream = file.openRead();
      int sentBytes = 0;
      final stopwatch = Stopwatch()..start();

      await for (final chunk in stream) {
        final chunkData = Uint8List.fromList(chunk);

        await _connectionService.sendFileChunk(peerIp, task.id, chunkData);

        sentBytes += chunkData.length;
        task.transferredBytes = sentBytes;
        task.speed = sentBytes / (stopwatch.elapsedMilliseconds / 1000);
        _taskUpdateController.add(task);
      }

      await _connectionService.sendMessage(peerIp, {
        'type': 'file_complete',
        'task_id': task.id,
        'sha256': task.sha256,
      });

    } catch (e) {
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      _taskUpdateController.add(task);
    }
  }

  void _handleFileChunk(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null || task.filePath == null) return;

    try {
      final data = base64Decode(message['data']);
      final file = File(task.filePath!);
      file.writeAsBytesSync(data, mode: FileMode.append);

      task.transferredBytes += data.length;
      _taskUpdateController.add(task);
    } catch (e) {
      debugPrint('File chunk error: $e');
    }
  }

  void _handleFileComplete(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null || task.filePath == null) return;

    _verifyReceivedFile(task, message['sha256'], sourceIp);
  }

  Future<void> _verifyReceivedFile(FileTransferTask task, String expectedSha256, String peerIp) async {
    try {
      final actualSha256 = await CryptoUtils.computeFileSha256(task.filePath!);

      if (actualSha256 == expectedSha256) {
        task.status = TransferStatus.completed;
        _taskUpdateController.add(task);

        await _connectionService.sendMessage(peerIp, {
          'type': 'file_verified',
          'task_id': task.id,
        });
      } else {
        task.status = TransferStatus.failed;
        task.errorMessage = '文件校验失败';
        _taskUpdateController.add(task);

        await _connectionService.sendMessage(peerIp, {
          'type': 'file_failed',
          'task_id': task.id,
        });
      }
    } catch (e) {
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      _taskUpdateController.add(task);
    }
  }

  void _handleFileVerified(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null) return;

    task.status = TransferStatus.completed;
    _taskUpdateController.add(task);
  }

  void _handleFileFailed(Map<String, dynamic> message, String sourceIp) {
    final taskId = message['task_id'] as String;
    final task = _tasks[taskId];
    if (task == null) return;

    task.status = TransferStatus.failed;
    task.errorMessage = '文件校验失败';
    _taskUpdateController.add(task);
  }

  void dispose() {
    _taskUpdateController.close();
    _incomingRequestController.close();
  }
}
