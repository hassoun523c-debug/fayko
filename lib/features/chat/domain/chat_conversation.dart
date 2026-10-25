import '../../users/domain/public_user.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participant,
    required this.unreadCount,
    required this.createdAt,
    this.lastMessageBody,
    this.lastMessageAt,
  });

  final String id;
  final PublicUser participant;
  final int unreadCount;
  final DateTime createdAt;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final participantJson = json['participant'];
    if (participantJson is! Map<String, dynamic>) {
      throw const FormatException('Conversation has no participant profile.');
    }

    final lastMessage = json['lastMessage'];
    final lastMessageMap = lastMessage is Map<String, dynamic>
        ? lastMessage
        : null;

    return ChatConversation(
      id: json['id'] as String,
      participant: PublicUser.fromJson(participantJson),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastMessageBody: lastMessageMap?['body'] as String?,
      lastMessageAt: DateTime.tryParse(
        lastMessageMap?['createdAt'] as String? ?? '',
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    required this.sender,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String body;
  final String senderId;
  final PublicUser sender;
  final DateTime createdAt;
  final bool isMine;

  ChatMessage copyWith({bool? isMine}) {
    return ChatMessage(
      id: id,
      body: body,
      senderId: senderId,
      sender: sender,
      createdAt: createdAt,
      isMine: isMine ?? this.isMine,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    if (senderJson is! Map<String, dynamic>) {
      throw const FormatException('Message has no sender profile.');
    }

    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String,
      senderId: json['senderId'] as String,
      sender: PublicUser.fromJson(senderJson),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isMine: json['isMine'] as bool? ?? false,
    );
  }
}
