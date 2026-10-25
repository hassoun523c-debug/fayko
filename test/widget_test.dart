import 'package:fayko/features/auth/data/auth_repository.dart';
import 'package:fayko/features/auth/domain/auth_user.dart';
import 'package:fayko/features/feed/data/feed_repository.dart';
import 'package:fayko/features/feed/domain/feed_post.dart';
import 'package:fayko/features/feed/presentation/feed_screen.dart';
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

    expect(find.text('فايكو ريلز'), findsOneWidget);
    expect(find.textContaining('الفيديوهات القصيرة'), findsOneWidget);
  });

  testWidgets('bottom navigation opens the chat section', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('الدردشة'));
    await tester.pumpAndSettle();

    expect(find.text('المحادثات'), findsOneWidget);
    expect(find.textContaining('نظام الرسائل اللحظية'), findsOneWidget);
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
