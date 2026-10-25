import 'chat_realtime.dart';

class NoopChatRealtime implements ChatRealtime {
  const NoopChatRealtime();

  @override
  void connect(String accessToken) {}

  @override
  void disconnect() {}

  @override
  void Function() listenForMessages({
    required String conversationId,
    required void Function(Map<String, dynamic> message) onMessage,
  }) =>
      () {};

  @override
  void Function() listenForInboxUpdates(
    void Function(String conversationId) onUpdate,
  ) =>
      () {};
}
