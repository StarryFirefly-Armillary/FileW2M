import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/connection_service.dart';

class MessageProvider extends ChangeNotifier {
  late final MessageService _messageService;
  StreamSubscription? _messageSubscription;

  // Callback for showing in-app notification
  Function(String deviceName, String content)? onMessageReceived;

  List<ChatMessage> get messages => _messageService.messages;
  MessageService get messageService => _messageService;

  MessageProvider();

  void init(ConnectionService connectionService) {
    _messageService = MessageService(connectionService);
    _messageService.init();

    _messageSubscription = _messageService.messageStream.listen((message) {
      notifyListeners();

      // Show in-app notification for received messages
      if (!message.isSent && onMessageReceived != null) {
        onMessageReceived!(message.peerDeviceName, message.content);
      }
    });
  }

  Future<void> sendMessage(String content, String peerIp, String peerDeviceName) async {
    await _messageService.sendMessage(content, peerIp, peerDeviceName);
  }

  List<ChatMessage> getMessagesForPeer(String peerId) {
    return _messageService.getMessagesForPeer(peerId);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageService.dispose();
    super.dispose();
  }
}
