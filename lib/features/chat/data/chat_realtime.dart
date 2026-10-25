import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/api_client.dart';

abstract interface class ChatRealtime {
  void connect(String accessToken);

  void disconnect();

  void Function() listenForMessages({
    required String conversationId,
    required void Function(Map<String, dynamic> message) onMessage,
  });

  void Function() listenForInboxUpdates(
    void Function(String conversationId) onUpdate,
  );
}

class SocketChatRealtimeClient implements ChatRealtime {
  SocketChatRealtimeClient({String? serverUrl})
      : _serverUrl = serverUrl ?? Uri.parse(faykoApiBaseUrl).origin;

  final String _serverUrl;
  io.Socket? _socket;
  String? _accessToken;

  @override
  void connect(String accessToken) {
    if (accessToken.isEmpty) return;
    if (_socket != null && _accessToken == accessToken) return;

    disconnect();
    _accessToken = accessToken;
    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({'token': accessToken})
          .build(),
    )..connect();
  }

  @override
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _accessToken = null;
  }

  @override
  void Function() listenForMessages({
    required String conversationId,
    required void Function(Map<String, dynamic> message) onMessage,
  }) {
    final socket = _socket;
    if (socket == null) return () {};

    void joinConversation() {
      socket.emit('conversation:join', {'conversationId': conversationId});
    }

    void handleMessage(dynamic payload) {
      if (payload is! Map) return;
      final message = Map<String, dynamic>.from(payload);
      if (message['conversationId'] != conversationId) return;
      onMessage(message);
    }

    socket.on('connect', (_) => joinConversation());
    socket.on('message:new', handleMessage);
    if (socket.connected) joinConversation();

    return () {
      socket.off('connect', joinConversation);
      socket.off('message:new', handleMessage);
      if (socket.connected) {
        socket.emit('conversation:leave', {
          'conversationId': conversationId,
        });
      }
    };
  }

  @override
  void Function() listenForInboxUpdates(
    void Function(String conversationId) onUpdate,
  ) {
    final socket = _socket;
    if (socket == null) return () {};

    void handleUpdate(dynamic payload) {
      if (payload is! Map || payload['conversationId'] is! String) return;
      onUpdate(payload['conversationId'] as String);
    }

    socket.on('conversation:updated', handleUpdate);
    return () => socket.off('conversation:updated', handleUpdate);
  }
}
