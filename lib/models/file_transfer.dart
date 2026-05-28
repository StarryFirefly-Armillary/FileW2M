enum TransferStatus {
  pending,
  transferring,
  completed,
  failed,
  cancelled,
}

enum TransferDirection { send, receive }

class FileTransferTask {
  final String id;
  final String fileName;
  final int fileSize;
  String? filePath;
  final String? sha256;
  final String peerDeviceId;
  final String peerDeviceName;
  final TransferDirection direction;
  TransferStatus status;
  int transferredBytes;
  double speed; // bytes per second
  DateTime startTime;
  String? errorMessage;

  FileTransferTask({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.filePath,
    this.sha256,
    required this.peerDeviceId,
    required this.peerDeviceName,
    required this.direction,
    this.status = TransferStatus.pending,
    this.transferredBytes = 0,
    this.speed = 0,
    DateTime? startTime,
    this.errorMessage,
  }) : startTime = startTime ?? DateTime.now();

  double get progress => fileSize > 0 ? transferredBytes / fileSize : 0;

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get sizeLabel => _formatBytes(fileSize);

  String get transferredLabel => _formatBytes(transferredBytes);

  String get speedLabel => '${_formatBytes(speed.round())}/s';

  String get remainingTime {
    if (speed <= 0 || transferredBytes >= fileSize) return '--';
    final remaining = (fileSize - transferredBytes) / speed;
    if (remaining < 60) return '${remaining.round()}秒';
    if (remaining < 3600) return '${(remaining / 60).round()}分钟';
    return '${(remaining / 3600).round()}小时';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
