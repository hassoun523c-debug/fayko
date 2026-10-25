import 'package:fayko/features/auth/data/auth_repository.dart';
import 'package:fayko/features/chat/data/chat_repository.dart';
import 'package:fayko/features/chat/data/noop_chat_realtime.dart';
import 'package:fayko/features/chat/domain/chat_conversation.dart';
import 'package:fayko/features/auth/domain/auth_user.dart';
import 'package:fayko/features/feed/data/feed_repository.dart';
import 'package:fayko/features/feed/domain/feed_post.dart';
import 'package:fayko/features/feed/presentation/feed_screen.dart';
import 'package:fayko/features/users/data/users_repository.dart';
import 'package:fayko/features/users/domain/public_user.dart';
import 'package:fayko/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1',
  username: 'hassoun',
  email: 'hassoun@example.com',
  displayName: 'حيدر',
  bio: '',
);
const _session = AuthSession(user: _user, accessToken: 'test-token');
const _publicCurrentUser = PublicUser(
  id: 'bb27c8a6-8c1a-4686-9478-33a7a7b7c3e1',
  username: 'hassoun',
  displayName: 'حيدر',
  bio: '',
  postsCount: 0,
  followersCount: 0,
  followingCount: 0,
  isFollowing: false,
);
const _otherUser = PublicUser(
  id: 'f7f0d84d-a8f4-4666-8f13-1f1145483b2c',
  username: 'test_user',
  displayName: 'مستخدم للاختبار',
  bio: 'حساب فايكو',
  postsCount: 2,
  followersCount: 4,
  followingCount: 3,
  isFollowing: false,
);

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({this.restore = true});

  final bool restore;

  @override
  Future<AuthSession?> restoreSession() async => restore ? _session : null;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async =>
      _session;

  @override
  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async =>
      _session;

  @override
  Future<AuthUser> updateProfile({
    required String accessToken,
    required String displayName,
    required String bio,
  }) async =>
      _user.copyWith(displayName: displayName, bio: bio);

  @override
  Future<void> logout() async {}
}

class _FakeChatRepository implements ChatRepository {
  const _FakeChatRepository();

  @override
  Future<List<ChatConversation>> loadConversations({
    required String accessToken,
  }) async =>
      [];

  @override
  Future<String> openDirect({
    required String accessToken,
    required String userId,
  }) async =>
      'conversation-test';

  @override
  Future<List<ChatMessage>> loadMessages({
    required String accessToken,
    required String conversationId,
  }) async =>
      [];

  @override
  Future<ChatMessage> sendMessage({
    required String accessToken,
    required String conversationId,
    required String body,
  }) async =>
      ChatMessage(
        id: 'sent-message',
        body: body,
        senderId: _user.id,
        sender: _publicCurrentUser,
        createdAt: DateTime.now(),
        isMine: true,
      );
}

class _FakeUsersRepository implements UsersRepository {
  const _FakeUsersRepository();

  @override
  Future<List<PublicUser>> searchUsers({
    required String accessToken,
    required String query,
  }) async =>
      [_otherUser];

  @override
  Future<void> setFollowing({
    required String accessToken,
    required PublicUser user,
    required bool following,
  }) async {}

  @override
  Future<List<PublicUser>> loadBlockedUsers({
    required String accessToken,
  }) async =>
      [_otherUser];

  @override
  Future<void> setBlocked({
    required String accessToken,
    required PublicUser user,
    required bool blocked,
  }) async {}

  @override
  Future<void> reportUser({
    required String accessToken,
    required PublicUser user,
    required String reason,
    String details = '',
  }) async {}
}

class _FakeFeedRepository implements FeedRepository {
  const _FakeFeedRepository();

  @override
  Future<List<FeedPost>> loadFeed({required String accessToken}) async => [];

  @override
  Future<FeedPost> createPost({
    required String accessToken,
    required String body,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> setLiked({
    required String accessToken,
    required FeedPost post,
    required bool liked,
  }) async {}

  @override
  Future<List<FeedComment>> loadComments({
    required String accessToken,
    required String postId,
  }) async =>
      [];

  @override
  Future<FeedComment> createComment({
    required String accessToken,
    required String postId,
    required String body,
  }) async =>
      throw UnimplementedError();
}

Widget _app({bool authenticated = true}) {
  return FaykoApp(
    authRepository: _FakeAuthRepository(restore: authenticated),
    feedRepository: const _FakeFeedRepository(),
    usersRepository: const _FakeUsersRepository(),
    chatRepository: const _FakeChatRepository(),
    chatRealtime: const NoopChatRealtime(),
  );
}

void main() {
  testWidgets('shows the Arabic feed in right-to-left direction', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('فايكو'), findsOneWidget);
    expect(find.textContaining('أهلاً بك في فايكو'), findsOneWidget);
    expect(find.text('ماكو منشورات لحد الآن'), findsOneWidget);

    final direction = Directionality.of(
      tester.element(find.byType(FeedScreen)),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('bottom navigation opens the reels section', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ريلز'));
    await tester.pumpAndSettle();

    expect(find.text('ذوقك في فايكو'), findsOneWidget);
    expect(find.text('رياضة'), findsOneWidget);
    expect(find.text('ترندات العالم'), findsOneWidget);
    expect(find.text('تشغيل الريلز قيد التطوير'), findsOneWidget);
  });

  testWidgets('bottom navigation opens the chat section', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('الدردشة'));
    await tester.pumpAndSettle();

    expect(find.text('المحادثات'), findsOneWidget);
    expect(find.text('ماكو محادثات بعد'), findsOneWidget);
  });

  testWidgets('text messages can be sent from a direct chat', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البحث عن المستخدمين'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test');
    await tester.tap(find.byTooltip('بحث'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مستخدم للاختبار'));
    await tester.pumpAndSettle();
    expect(find.text('هذه بداية المحادثة. اكتب أول رسالة.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'رسالة اختبار');
    await tester.tap(find.byTooltip('إرسال الرسالة'));
    await tester.pumpAndSettle();

    expect(find.text('رسالة اختبار'), findsOneWidget);
  });

  testWidgets('user search displays matching users and follows them', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البحث عن المستخدمين'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'test');
    await tester.tap(find.byTooltip('بحث'));
    await tester.pumpAndSettle();

    expect(find.text('مستخدم للاختبار'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    expect(find.text('تتابعه'), findsOneWidget);
  });

  testWidgets('user report sends a selected reason', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('البحث عن المستخدمين'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test');
    await tester.tap(find.byTooltip('بحث'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('خيارات الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إبلاغ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رسائل مزعجة أو إعلانات'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تم إرسال البلاغ'), findsOneWidget);
  });

  testWidgets('blocked accounts can be unblocked from the profile', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الحسابات المحظورة'));
    await tester.pumpAndSettle();

    expect(find.text('مستخدم للاختبار'), findsOneWidget);
    await tester.tap(find.text('إلغاء الحظر'));
    await tester.pumpAndSettle();

    expect(find.text('ماكو حسابات محظورة'), findsOneWidget);
  });

  testWidgets('profile edits are submitted and reflected in the screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل الملف الشخصي'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'اسم جديد');
    await tester.enterText(fields.at(1), 'نبذة جديدة');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('اسم جديد'), findsOneWidget);
    expect(find.text('نبذة جديدة'), findsOneWidget);
  });

  testWidgets('shows login and registration when there is no saved session', (
    tester,
  ) async {
    await tester.pumpWidget(_app(authenticated: false));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.textContaining('إنشاء حساب جديد'), findsOneWidget);
  });
}
