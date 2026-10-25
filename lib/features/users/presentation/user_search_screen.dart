import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/chat_realtime.dart';
import '../../chat/presentation/chat_screens.dart';
import '../../auth/domain/auth_user.dart';
import '../data/users_repository.dart';
import '../domain/public_user.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.chatRepository,
    required this.realtime,
  });

  final AuthSession session;
  final UsersRepository repository;
  final ChatRepository chatRepository;
  final ChatRealtime realtime;

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _controller = TextEditingController();
  List<PublicUser> _users = const [];
  bool _loading = false;
  final Set<String> _busyUsers = <String>{};
  String? _error;
  String? _lastQuery;
  int _requestVersion = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final requestVersion = ++_requestVersion;
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() {
        _users = const [];
        _loading = false;
        _error = 'اكتب حرفين على الأقل للبحث.';
        _lastQuery = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });

    try {
      final users = await widget.repository.searchUsers(
        accessToken: widget.session.accessToken,
        query: query,
      );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _users = users;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'تعذر البحث عن المستخدمين.';
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openChat(PublicUser user) async {
    if (user.id == widget.session.user.id) return;

    try {
      final conversationId = await widget.chatRepository.openDirect(
        accessToken: widget.session.accessToken,
        userId: user.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: ChatThreadScreen(
              session: widget.session,
              conversationId: conversationId,
              participant: user,
              repository: widget.chatRepository,
              realtime: widget.realtime,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'تعذر فتح المحادثة. حاول مرة ثانية.',
          ),
        ),
      );
    }
  }

  Future<void> _blockUser(PublicUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حظر الحساب'),
        content: Text(
          'راح تخفي منشورات @${user.username} وتمنع التواصل معه أثناء الحظر. تگدر تلغي الحظر من إعدادات الحساب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حظر'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUsers.add(user.id));
    try {
      await widget.repository.setBlocked(
        accessToken: widget.session.accessToken,
        user: user,
        blocked: true,
      );
      if (!mounted) return;
      setState(() => _users.removeWhere((item) => item.id == user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حظر @${user.username}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'تعذر حظر الحساب.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUsers.remove(user.id));
    }
  }

  Future<void> _reportUser(PublicUser user) async {
    const reasons = <String, String>{
      'spam': 'رسائل مزعجة أو إعلانات',
      'harassment': 'مضايقة أو تنمّر',
      'hate_or_discrimination': 'كراهية أو تمييز',
      'sexual_content': 'محتوى جنسي غير مناسب',
      'violence': 'عنف أو تهديد',
      'scam_or_fraud': 'احتيال أو نصب',
      'impersonation': 'انتحال شخصية',
      'other': 'سبب آخر',
    };

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('الإبلاغ عن @${user.username}'),
        children: [
          for (final item in reasons.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(item.key),
              child: Text(item.value),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _busyUsers.add(user.id));
    try {
      await widget.repository.reportUser(
        accessToken: widget.session.accessToken,
        user: user,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استلام البلاغ وحفظه للنظر فيه عند توفر مراجعة.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'تعذر إرسال البلاغ.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busyUsers.remove(user.id));
    }
  }

  Future<void> _toggleFollow(PublicUser user) async {
    if (_busyUsers.contains(user.id)) return;
    final following = !user.isFollowing;
    setState(() => _busyUsers.add(user.id));

    try {
      await widget.repository.setFollowing(
        accessToken: widget.session.accessToken,
        user: user,
        following: following,
      );
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((item) => item.id == user.id);
        if (index >= 0) {
          _users[index] = user.copyWith(
            isFollowing: following,
            followersCount: (user.followersCount + (following ? 1 : -1))
                .clamp(0, 1 << 30)
                .toInt(),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'تعذر تحديث المتابعة.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUsers.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('اكتشف')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'اسم المستخدم أو الاسم الظاهر',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'بحث',
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            Expanded(
              child: _loading && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              _lastQuery == null
                                  ? 'ابحث عن اسم مستخدم حتى تكتشف حسابات فايكو.'
                                  : 'ما لقينا حسابات تطابق البحث.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final busy = _busyUsers.contains(user.id);
                            return ListTile(
                              onTap: user.id == widget.session.user.id
                                  ? null
                                  : () => _openChat(user),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: colors.primaryContainer,
                                child: Text(
                                  user.displayName.isEmpty
                                      ? '?'
                                      : user.displayName.characters.first,
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '@${user.username} · ${user.followersCount} متابع',
                                ),
                              ),
                              trailing: user.id == widget.session.user.id
                                  ? const Text('حسابك')
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 96,
                                          child: OutlinedButton(
                                            onPressed: busy
                                                ? null
                                                : () => _toggleFollow(user),
                                            child: busy
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Text(
                                                    user.isFollowing
                                                        ? 'تتابعه'
                                                        : 'متابعة',
                                                  ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'خيارات الحساب',
                                          enabled: !busy,
                                          onSelected: (value) {
                                            if (value == 'report') {
                                              _reportUser(user);
                                            } else if (value == 'block') {
                                              _blockUser(user);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'report',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.flag_outlined),
                                                  SizedBox(width: 10),
                                                  Text('إبلاغ'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'block',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.block_outlined),
                                                  SizedBox(width: 10),
                                                  Text('حظر'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
