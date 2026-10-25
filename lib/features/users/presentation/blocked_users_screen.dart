import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_user.dart';
import '../data/users_repository.dart';
import '../domain/public_user.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final AuthSession session;
  final UsersRepository repository;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<PublicUser> _users = const [];
  final Set<String> _pending = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.repository.loadBlockedUsers(
        accessToken: widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'تعذر تحميل الحسابات المحظورة.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(PublicUser user) async {
    if (_pending.contains(user.id)) return;
    setState(() => _pending.add(user.id));
    try {
      await widget.repository.setBlocked(
        accessToken: widget.session.accessToken,
        user: user,
        blocked: false,
      );
      if (!mounted) return;
      setState(() => _users.removeWhere((item) => item.id == user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إلغاء حظر @${user.username}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'تعذر إلغاء الحظر. حاول مجدداً.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات المحظورة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'الحسابات المحظورة لا تظهر لك في البحث والخلاصة، ولن تتمكن من مواصلة المحادثة معها أثناء الحظر.',
              ),
              const SizedBox(height: 16),
              if (_loading && _users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _loadUsers,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              else if (_users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.block_outlined, size: 44),
                      SizedBox(height: 12),
                      Text(
                        'ماكو حسابات محظورة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                )
              else
                for (final user in _users)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          user.displayName.isEmpty
                              ? '?'
                              : user.displayName.characters.first,
                          style: TextStyle(color: colors.onPrimaryContainer),
                        ),
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('@${user.username}'),
                      trailing: OutlinedButton(
                        onPressed: _pending.contains(user.id)
                            ? null
                            : () => _unblock(user),
                        child: _pending.contains(user.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('إلغاء الحظر'),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
