import '../../../core/network/api_client.dart';
import '../domain/chat_conversation.dart';

abstract interface class ChatRepository {
  Future<List<ChatConversation>> loadConversations({
    required String accessToken,
  });

  Future<String> openDirect({
    required String accessToken,
    required String userId,
  });

  Future<List<ChatMessage>> loadMessages({
    required String accessToken,
    required String conversationId,
  });

  Future<ChatMessage> sendMessage({
    required String accessToken,
    required String conversationId,
    required String body,
  });
}

class RemoteChatRepository implements ChatRepository {
  const RemoteChatRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ChatConversation>> loadConversations({
    required String accessToken,
  }) async {
    final payload = await _apiClient.get(
      '/conversations',
      token: accessToken,
    );
    final raw = payload['conversations'];
    if (raw is! List) {
      throw const FormatException('Invalid conversation-list response.');
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> openDirect({
    required String accessToken,
    required String userId,
  }) async {
    final payload = await _apiClient.post(
      '/conversations/direct',
      token: accessToken,
      body: {'userId': userId},
    );
    final conversation = payload['conversation'];
    if (conversation is! Map<String, dynamic> ||
        conversation['id'] is! String) {
      throw const FormatException('Invalid direct-conversation response.');
    }
    return conversation['id'] as String;
  }

  @override
  Future<List<ChatMessage>> loadMessages({
    required String accessToken,
    required String conversationId,
  }) async {
    final payload = await _apiClient.get(
      '/conversations/' + conversationId + '/messages',
      token: accessToken,
      queryParameters: {'limit': '50'},
    );
    final raw = payload['messages'];
    if (raw is! List) {
      throw const FormatException('Invalid message-list response.');
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String accessToken,
    required String conversationId,
    required String body,
  }) async {
    final payload = await _apiClient.post(
      '/conversations/' + conversationId + '/messages',
      token: accessToken,
      body: {'body': body},
    );
    final raw = payload['message'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid send-message response.');
    }
    return ChatMessage.fromJson(raw);
  }
}
