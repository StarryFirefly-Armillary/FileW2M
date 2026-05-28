import 'dart:async';
import '../models/message.dart';
import 'connection_service.dart';
import 'notification_service.dart';

class MessageService {
  final ConnectionService _connectionService;
  final NotificationService _notificationService = NotificationService();
  final List<ChatMessage> _messages = [];
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  MessageService(this._connectionService);

  void init() {
    _connectionService.messages.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type != 'text_message') return;

    final sourceIp = message['_source_ip'] as String;
    final chatMessage = ChatMessage(
      id: message['message_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      peerDeviceId: sourceIp,
      peerDeviceName: message['peer_device_name'] ?? sourceIp,
      content: message['content'],
      type: MessageType.text,
      isSent: false,
      timestamp: DateTime.now(),
    );

    _messages.add(chatMessage);
    _messageController.add(chatMessage);

    // Show system notification for received message
    _notificationService.showMessageNotification(
      title: chatMessage.peerDeviceName,
      body: chatMessage.content,
    );
  }

  Future<void> sendMessage(String content, String peerIp, String peerDeviceName) async {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      peerDeviceId: peerIp,
      peerDeviceName: peerDeviceName,
      content: content,
      type: MessageType.text,
      isSent: true,
      timestamp: DateTime.now(),
    );

    _messages.add(message);
    _messageController.add(message);

    await _connectionService.sendMessage(peerIp, {
      'type': 'text_message',
      'message_id': message.id,
      'content': content,
      'peer_device_name': peerDeviceName,
    });
  }

  List<ChatMessage> getMessagesForPeer(String peerId) {
    return _messages.where((m) => m.peerDeviceId == peerId).toList();
  }

  void dispose() {
    _messageController.close();
  }
}
