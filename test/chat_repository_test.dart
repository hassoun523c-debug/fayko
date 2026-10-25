import 'dart:convert';

import 'package:fayko/core/network/api_client.dart';
import 'package:fayko/features/chat/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chat repository parses inbox and persists a direct text message', () async {
    final api = ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        expect(
          request.headers['authorization'],
          'Bearer chat-test-token',
        );

        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'id': 'conversation-test',
                  'createdAt': '2026-10-25T12:00:00.000Z',
                  'lastReadAt': '2026-10-25T12:00:00.000Z',
                  'participant': {
                    'id': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
                    'username': 'test_user',
                    'displayName': 'مستخدم للاختبار',
                    'avatarUrl': null,
                  },
                  'lastMessage': {
                    'id': 'message-old',
                    'body': 'رسالة سابقة',
                    'createdAt': '2026-10-25T12:01:00.000Z',
                    'senderId': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
                  },
                  'unreadCount': 2,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/api/v1/conversations/direct') {
          expect(jsonDecode(request.body), {
            'userId': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
          });
          return http.Response(
            jsonEncode({
              'conversation': {
                'id': 'conversation-test',
                'participantId': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
              },
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.url.path ==
            '/api/v1/conversations/conversation-test/messages') {
          if (request.method == 'GET') {
            expect(request.url.queryParameters['limit'], '50');
            return http.Response(
              jsonEncode({
                'messages': [
                  {
                    'id': 'message-old',
                    'body': 'رسالة سابقة',
                    'createdAt': '2026-10-25T12:01:00.000Z',
                    'senderId': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
                    'sender': {
                      'id': 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
                      'username': 'test_user',
                      'displayName': 'مستخدم للاختبار',
                      'avatarUrl': null,
                    },
                    'isMine': false,
                  },
                ],
                'nextCursor': null,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {'body': 'رسالة جديدة'});
            return http.Response(
              jsonEncode({
                'message': {
                  'id': 'message-new',
                  'body': 'رسالة جديدة',
                  'createdAt': '2026-10-25T12:02:00.000Z',
                  'senderId': 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1',
                  'sender': {
                    'id': 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1',
                    'username': 'hassoun',
                    'displayName': 'حيدر',
                    'avatarUrl': null,
                  },
                  'isMine': true,
                },
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
        }

        return http.Response(
          jsonEncode({
            'error': {'code': 'unexpected_test_request', 'message': 'Unexpected request'},
          }),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final repository = RemoteChatRepository(apiClient: api);

    final conversations = await repository.loadConversations(
      accessToken: 'chat-test-token',
    );
    expect(conversations, hasLength(1));
    expect(conversations.single.participant.username, 'test_user');
    expect(conversations.single.unreadCount, 2);
    expect(conversations.single.lastMessageBody, 'رسالة سابقة');

    final directId = await repository.openDirect(
      accessToken: 'chat-test-token',
      userId: 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
    );
    expect(directId, 'conversation-test');

    final messages = await repository.loadMessages(
      accessToken: 'chat-test-token',
      conversationId: directId,
    );
    expect(messages, hasLength(1));
    expect(messages.single.isMine, false);
    expect(messages.single.body, 'رسالة سابقة');

    final sent = await repository.sendMessage(
      accessToken: 'chat-test-token',
      conversationId: directId,
      body: 'رسالة جديدة',
    );
    expect(sent.body, 'رسالة جديدة');
    expect(sent.isMine, true);

    api.close();
  });
}
