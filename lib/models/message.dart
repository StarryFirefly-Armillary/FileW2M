enum MessageType { text, file }

class ChatMessage {
  final String id;
  final String peerDeviceId;
  final String peerDeviceName;
  final String content;
  final MessageType type;
  final bool isSent; // true = sent by us, false = received
  final DateTime timestamp;
  final String? fileName;
  final int? fileSize;

  ChatMessage({
    required this.id,
    required this.peerDeviceId,
    required this.peerDeviceName,
    required this.content,
    required this.type,
    required this.isSent,
    required this.timestamp,
    this.fileName,
    this.fileSize,
  });

  String get fileSizeLabel {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
