import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/chat_screens.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/profile/presentation/edit_profile_dialog.dart';
import '../features/users/data/users_repository.dart';
import '../features/users/presentation/user_search_screen.dart';

class FaykoApp extends StatelessWidget {
  const FaykoApp({
    super.key,
    this.authRepository,
    this.feedRepository,
    this.usersRepository,
    this.chatRepository,
  });

  final AuthRepository? authRepository;
  final FeedRepository? feedRepository;
  final UsersRepository? usersRepository;
  final ChatRepository? chatRepository;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF000000);
    const panel = Color(0xFF151515);
    const accent = Color(0xFFE85D75);

    return MaterialApp(
      title: 'فايكو | Fayko',
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AuthGate(
          authRepository: authRepository,
          feedRepository: feedRepository,
          usersRepository: usersRepository,
          chatRepository: chatRepository,
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
  });

  final AuthRepository? authRepository;
  final FeedRepository? feedRepository;
  final UsersRepository? usersRepository;
  final ChatRepository? chatRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final FeedRepository _feedRepository;
  late final UsersRepository _usersRepository;
  late final ChatRepository _chatRepository;
  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();

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
    _restoreSession();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _authRepository.restoreSession();
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

  String _friendlyError(Object error, String fallback) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'استجابة الخادم غير صالحة. حاول لاحقاً.';
    }
    return fallback;
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
          'فايكو',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'البحث عن المستخدمين',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: UserSearchScreen(
                      session: session,
                      repository: _usersRepository,
                      chatRepository: _chatRepository,
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 4),
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
          const _ComingSoon(
            icon: Icons.play_circle_outline,
            title: 'فايكو ريلز',
            description: 'الفيديوهات القصيرة تحتاج مرحلة رفع ومعالجة الفيديو.',
          ),
          ChatListScreen(
            session: session,
            repository: _chatRepository,
          ),
          _ProfileScreen(
            user: session.user,
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
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'ريلز',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'الدردشة',
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
    required this.user,
    required this.onLogout,
    required this.onUpdateProfile,
  });

  final AuthUser user;
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
          '@' + user.username,
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
