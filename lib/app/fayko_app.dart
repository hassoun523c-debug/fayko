import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/chat_realtime.dart';
import '../features/chat/presentation/chat_screens.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/reels/data/reels_repository.dart';
import '../features/reels/presentation/reels_screen.dart';
import '../features/profile/presentation/edit_profile_dialog.dart';
import '../features/users/data/users_repository.dart';
import '../features/users/presentation/user_search_screen.dart';
import '../features/users/presentation/blocked_users_screen.dart';

const vemblixPreviewMode = bool.fromEnvironment(
  'VEMBLIX_PREVIEW_MODE',
  defaultValue: false,
);

class FaykoApp extends StatelessWidget {
  const FaykoApp({
    super.key,
    this.authRepository,
    this.feedRepository,
    this.usersRepository,
    this.chatRepository,
    this.chatRealtime,
    this.reelsRepository,
  });

  final AuthRepository? authRepository;
  final FeedRepository? feedRepository;
  final UsersRepository? usersRepository;
  final ChatRepository? chatRepository;
  final ChatRealtime? chatRealtime;
  final ReelsRepository? reelsRepository;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF000000);
    const panel = Color(0xFF151515);
    const accent = Color(0xFFE85D75);

    return MaterialApp(
      title: 'Vemblix',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: panel,
        ),
        scaffoldBackgroundColor: ink,
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: panel,
          indicatorColor: Color(0x33E85D75),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
        ),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AuthGate(
          authRepository: authRepository,
          feedRepository: feedRepository,
          usersRepository: usersRepository,
          chatRepository: chatRepository,
          chatRealtime: chatRealtime,
          reelsRepository: reelsRepository,
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authRepository,
    this.feedRepository,
    this.usersRepository,
    this.chatRepository,
    this.chatRealtime,
    this.reelsRepository,
  });

  final AuthRepository? authRepository;
  final FeedRepository? feedRepository;
  final UsersRepository? usersRepository;
  final ChatRepository? chatRepository;
  final ChatRealtime? chatRealtime;
  final ReelsRepository? reelsRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final FeedRepository _feedRepository;
  late final UsersRepository _usersRepository;
  late final ChatRepository _chatRepository;
  late final ChatRealtime _chatRealtime;
  late final ReelsRepository _reelsRepository;
  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();
  final GlobalKey<ChatListScreenState> _chatKey = GlobalKey<ChatListScreenState>();

  AuthSession? _session;
  bool _restoring = true;
  bool _busy = false;
  int _selectedIndex = 0;
  String? _startupError;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authRepository = widget.authRepository ??
        RemoteAuthRepository(
          apiClient: _apiClient,
          tokenStore: const SecureTokenStore(),
        );
    _feedRepository = widget.feedRepository ??
        RemoteFeedRepository(apiClient: _apiClient);
    _usersRepository = widget.usersRepository ??
        RemoteUsersRepository(apiClient: _apiClient);
    _chatRepository = widget.chatRepository ??
        RemoteChatRepository(apiClient: _apiClient);
    _chatRealtime = widget.chatRealtime ?? SocketChatRealtimeClient();
    _reelsRepository = widget.reelsRepository ?? RemoteReelsRepository(apiClient: _apiClient);
    _restoreSession();
  }

  @override
  void dispose() {
    _chatRealtime.disconnect();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    if (vemblixPreviewMode) {
      if (!mounted) return;
      setState(() {
        _session = const AuthSession(
          user: AuthUser(
            id: 'vemblix-preview-user',
            username: 'vemblix_demo',
            email: 'preview@vemblix.local',
            displayName: 'زائر Vemblix',
            bio: 'حساب تجريبي للمعاينة فقط',
            interests: [],
          ),
          accessToken: 'preview-token-not-for-real-api',
        );
        _restoring = false;
        _startupError = null;
      });
      return;
    }

    try {
      final session = await _authRepository.restoreSession();
      if (session != null) _chatRealtime.connect(session.accessToken);
      if (!mounted) return;
      setState(() {
        _session = session;
        _restoring = false;
        _startupError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _startupError = _friendlyError(
          error,
          'تعذر التحقق من جلسة الدخول. تحقق من اتصال الخادم.',
        );
      });
    }
  }

  Future<void> _login(String identifier, String password) async {
    setState(() {
      _busy = true;
      _authError = null;
    });
    try {
      final session = await _authRepository.login(
        identifier: identifier,
        password: password,
      );
      _chatRealtime.connect(session.accessToken);
      if (!mounted) return;
      setState(() {
        _session = session;
        _selectedIndex = 0;
        _startupError = null;
        _authError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = _friendlyError(
            error,
            'تعذر تسجيل الدخول. حاول مرة ثانية.',
          ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    setState(() {
      _busy = true;
      _authError = null;
    });
    try {
      final session = await _authRepository.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );
      _chatRealtime.connect(session.accessToken);
      if (!mounted) return;
      setState(() {
        _session = session;
        _selectedIndex = 0;
        _startupError = null;
        _authError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = _friendlyError(
            error,
            'تعذر إنشاء الحساب. تحقق من البيانات واتصال الخادم.',
          ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _authRepository.logout();
      _chatRealtime.disconnect();
      if (!mounted) return;
      setState(() {
        _session = null;
        _selectedIndex = 0;
        _authError = null;
        _startupError = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error, 'تعذر تسجيل الخروج.'))),
      );
    }
  }

  Future<void> _updateProfile(String displayName, String bio) async {
    final currentSession = _session;
    if (currentSession == null) return;

    final updatedUser = await _authRepository.updateProfile(
      accessToken: currentSession.accessToken,
      displayName: displayName,
      bio: bio,
    );

    if (!mounted) return;
    setState(() {
      _session = AuthSession(
        user: updatedUser,
        accessToken: currentSession.accessToken,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الملف الشخصي.')),
    );
  }

  Future<bool> _updateInterests(List<String> interests) async {
    final currentSession = _session;
    if (currentSession == null) return false;

    try {
      final payload = await _apiClient.patch(
        '/auth/me',
        token: currentSession.accessToken,
        body: {'interests': interests},
      );
      final rawUser = payload['user'];
      if (rawUser is! Map<String, dynamic>) {
        throw const FormatException('Invalid interests response.');
      }
      if (!mounted) return false;
      setState(() {
        _session = AuthSession(
          user: AuthUser.fromJson(rawUser),
          accessToken: currentSession.accessToken,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ اهتماماتك بحسابك.')),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error, 'تعذر حفظ الاهتمامات.'))),
        );
      }
      return false;
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'استجابة الخادم غير صالحة. حاول لاحقاً.';
    }
    return fallback;
  }

  void _showPreviewNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'الإشعارات',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0x33FF2E9C),
                    child: Icon(Icons.favorite_rounded, color: Color(0xFFFF2E9C)),
                  ),
                  title: Text('سارة أعجبت بمنشورك'),
                  subtitle: Text('منذ 5 دقائق'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0x338B5CF6),
                    child: Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: Text('أحمد بدأ بمتابعتك'),
                  subtitle: Text('منذ 12 دقيقة'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0x333282F6),
                    child: Icon(Icons.chat_bubble_rounded, color: Color(0xFF3282F6)),
                  ),
                  title: Text('لديك رسالة جديدة'),
                  subtitle: Text('افتح المراسلات لمشاهدتها'),
                ),
                Divider(),
                Text(
                  'إشعارات توضيحية للمعاينة فقط؛ الإشعارات الحقيقية تحتاج ربط الخادم.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = _session;
    if (session == null) {
      return AuthScreen(
        onLogin: _login,
        onRegister: _register,
        isBusy: _busy,
        errorMessage: _authError ?? _startupError,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vemblix',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (vemblixPreviewMode)
            IconButton(
              tooltip: 'الإشعارات التجريبية',
              onPressed: _showPreviewNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          if (vemblixPreviewMode)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: Center(
                child: Text(
                  'نسخة معاينة',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Text(
                'V',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE85D75),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FeedScreen(
            key: _feedKey,
            session: session,
            repository: _feedRepository,
          ),
          UserSearchScreen(
            key: const ValueKey('discover-screen'),
            session: session,
            repository: _usersRepository,
            chatRepository: _chatRepository,
            realtime: _chatRealtime,
          ),
          ReelsScreen(
            user: session.user,
            accessToken: session.accessToken,
            repository: _reelsRepository,
            onSaveInterests: _updateInterests,
          ),
          ChatListScreen(
            key: _chatKey,
            session: session,
            repository: _chatRepository,
            realtime: _chatRealtime,
          ),
          _ProfileScreen(
            session: session,
            user: session.user,
            usersRepository: _usersRepository,
            onLogout: _logout,
            onUpdateProfile: _updateProfile,
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              tooltip: 'منشور جديد',
              onPressed: () => _feedKey.currentState?.compose(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 3) _chatKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'اكتشف',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'ريلز',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'المراسلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({
    required this.session,
    required this.user,
    required this.usersRepository,
    required this.onLogout,
    required this.onUpdateProfile,
  });

  final AuthSession session;
  final AuthUser user;
  final UsersRepository usersRepository;
  final VoidCallback onLogout;
  final Future<void> Function(String displayName, String bio) onUpdateProfile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: colors.primaryContainer,
            child: Text(
              user.displayName.isEmpty ? '?' : user.displayName.characters.first,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          user.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(
          '@${user.username}',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => showEditProfileDialog(
            context: context,
            user: user,
            onSave: onUpdateProfile,
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل الملف الشخصي'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: BlockedUsersScreen(
                    session: session,
                    repository: usersRepository,
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.block_outlined),
          label: const Text('الحسابات المحظورة'),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('البريد الإلكتروني'),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('النبذة'),
                subtitle: Text(
                  user.bio.isEmpty ? 'ما أضفت نبذة بعد.' : user.bio,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج من هذا الجهاز'),
        ),
      ],
    );
  }
}

