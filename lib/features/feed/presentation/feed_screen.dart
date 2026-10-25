import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_user.dart';
import '../data/feed_repository.dart';
import '../domain/feed_post.dart';

class NewPostDraft {
  const NewPostDraft({required this.body, required this.category});

  final String body;
  final String category;
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final AuthSession session;
  final FeedRepository repository;

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<FeedPost> _posts = const [];
  bool _loading = true;
  String _selectedFeedCategory = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedFeedCategory = widget.session.user.interests.isEmpty ? 'all' : 'forYou';
    _loadFeed();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableInterests = widget.session.user.interests.toSet();
    if (_selectedFeedCategory != 'all' &&
        _selectedFeedCategory != 'forYou' &&
        !availableInterests.contains(_selectedFeedCategory)) {
      _selectedFeedCategory = 'forYou';
    }
  }

  List<FeedPost> get _visiblePosts {
    if (_selectedFeedCategory == 'all') return _posts;
    final interests = widget.session.user.interests.toSet();
    if (_selectedFeedCategory == 'forYou') {
      if (interests.isEmpty) return _posts;
      return _posts
          .where((post) => post.category == 'general' || interests.contains(post.category))
          .toList(growable: false);
    }
    return _posts
        .where((post) => post.category == _selectedFeedCategory)
        .toList(growable: false);
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() {
      _loading = _posts.isEmpty;
      _error = null;
    });

    try {
      final posts = await widget.repository.loadFeed(
        accessToken: widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error, 'تعذر تحميل المنشورات.');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> compose(BuildContext parentContext) async {
    final draft = await showModalBottomSheet<NewPostDraft>(
      context: parentContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const CreatePostSheet(),
      ),
    );
    if (draft == null || draft.body.trim().isEmpty || !mounted) return;

    try {
      final post = await widget.repository.createPost(
        accessToken: widget.session.accessToken,
        body: draft.body.trim(),
        category: draft.category,
      );
      if (!mounted) return;
      setState(() {
        _posts = [post, ..._posts.where((item) => item.id != post.id)];
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر منشورك.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(error, 'تعذر نشر المنشور.'))),
      );
    }
  }

  Future<void> _toggleLike(FeedPost post) async {
    final liked = !post.likedByMe;
    try {
      await widget.repository.setLiked(
        accessToken: widget.session.accessToken,
        post: post,
        liked: liked,
      );
      if (!mounted) return;
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index < 0) return;
      final count = (post.likesCount + (liked ? 1 : -1)).clamp(0, 1 << 30).toInt();
      setState(() {
        _posts[index] = post.copyWith(
          likedByMe: liked,
          likesCount: count,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(error, 'تعذر تحديث الإعجاب.'))),
      );
    }
  }

  Future<void> _openComments(FeedPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CommentsSheet(
        repository: widget.repository,
        accessToken: widget.session.accessToken,
        postId: post.id,
        onCommentAdded: () {
          if (!mounted) return;
          final index = _posts.indexWhere((item) => item.id == post.id);
          if (index < 0) return;
          setState(() {
            _posts[index] = _posts[index].copyWith(
              commentsCount: _posts[index].commentsCount + 1,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    widget.session.user.displayName.characters.first,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'أهلاً بك في فايكو، ${widget.session.user.displayName} 👋',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'الخلاصة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('لك'),
                selected: _selectedFeedCategory == 'forYou',
                onSelected: (_) => setState(() => _selectedFeedCategory = 'forYou'),
              ),
              FilterChip(
                label: const Text('الكل'),
                selected: _selectedFeedCategory == 'all',
                onSelected: (_) => setState(() => _selectedFeedCategory = 'all'),
              ),
              for (final category in widget.session.user.interests)
                FilterChip(
                  key: ValueKey('feed-filter-$category'),
                  label: Text(postCategoryLabel(category)),
                  selected: _selectedFeedCategory == category,
                  onSelected: (_) => setState(() => _selectedFeedCategory = category),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _posts.isEmpty)
            _FeedStatus(
              icon: Icons.cloud_off_outlined,
              title: 'ما قدرنا نحمل الخلاصة',
              description: _error!,
              actionLabel: 'إعادة المحاولة',
              onAction: _loadFeed,
            )
          else if (_posts.isEmpty)
            const _FeedStatus(
              icon: Icons.dynamic_feed_outlined,
              title: 'ماكو منشورات لحد الآن',
              description: 'اكتب أول منشور حتى يبدأ محتوى فايكو بالظهور هنا.',
            )
          else if (_visiblePosts.isEmpty)
            const _FeedStatus(
              icon: Icons.filter_list,
              title: 'ماكو منشورات بهالتصنيف بعد',
              description: 'جرّب تصنيفاً آخر أو ارجع إلى «الكل».',
            ),
          if (_error != null && _posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final post in _visiblePosts) _buildPostCard(post),
        ],
      ),
    );
  }

  Widget _buildPostCard(FeedPost post) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                child: Text(
                  post.author.displayName.isEmpty
                      ? '?'
                      : post.author.displayName.characters.first,
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '@${post.author.username} · ${_relativeTime(post.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(postCategoryLabel(post.category)),
            ),
          ),
          Text(
            post.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          Row(
            children: [
              IconButton(
                tooltip: post.likedByMe ? 'إلغاء الإعجاب' : 'إعجاب',
                onPressed: () => _toggleLike(post),
                icon: Icon(
                  post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: post.likedByMe ? colors.primary : null,
                ),
              ),
              Text(post.likesCount.toString()),
              const SizedBox(width: 18),
              IconButton(
                tooltip: 'التعليقات',
                onPressed: () => _openComments(post),
                icon: const Icon(Icons.mode_comment_outlined),
              ),
              Text(post.commentsCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  String _messageFor(Object error, String fallback) {
    if (error is ApiException) return error.message;
    return fallback;
  }

  String _relativeTime(DateTime date) {
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inSeconds < 60) return 'الآن';
    if (elapsed.inMinutes < 60) {
      return 'قبل ${elapsed.inMinutes} د';
    }
    if (elapsed.inHours < 24) {
      return 'قبل ${elapsed.inHours} س';
    }
    if (elapsed.inDays < 7) {
      return 'قبل ${elapsed.inDays} ي';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _controller = TextEditingController();
  String _selectedCategory = 'general';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'منشور جديد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'تصنيف المنشور',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('عام')),
                DropdownMenuItem(value: 'sports', child: Text('رياضة')),
                DropdownMenuItem(value: 'gaming', child: Text('ألعاب')),
                DropdownMenuItem(value: 'entertainment', child: Text('ترفيه')),
                DropdownMenuItem(value: 'religion', child: Text('ديني')),
                DropdownMenuItem(value: 'education', child: Text('تعليم')),
                DropdownMenuItem(value: 'design', child: Text('تصاميم')),
                DropdownMenuItem(value: 'technology', child: Text('تقنية')),
                DropdownMenuItem(value: 'news', child: Text('أخبار')),
                DropdownMenuItem(value: 'fashion', child: Text('أزياء')),
                DropdownMenuItem(value: 'cooking', child: Text('طبخ')),
                DropdownMenuItem(value: 'travel', child: Text('سفر')),
                DropdownMenuItem(value: 'science', child: Text('علوم')),
                DropdownMenuItem(value: 'comedy', child: Text('كوميديا')),
                DropdownMenuItem(value: 'art', child: Text('فنون')),
                DropdownMenuItem(value: 'global_trends', child: Text('ترندات العالم')),
              ],
              onChanged: (category) {
                if (category != null) {
                  setState(() => _selectedCategory = category);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 7,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'شنو حاب تشارك اليوم؟',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final text = _controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop(
                    NewPostDraft(body: text, category: _selectedCategory),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('نشر'),
            ),
          ],
        ),
      ),
    );
  }
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.repository,
    required this.accessToken,
    required this.postId,
    required this.onCommentAdded,
  });

  final FeedRepository repository;
  final String accessToken;
  final String postId;
  final VoidCallback onCommentAdded;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  List<FeedComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await widget.repository.loadComments(
        accessToken: widget.accessToken,
        postId: widget.postId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final comment = await widget.repository.createComment(
        accessToken: widget.accessToken,
        postId: widget.postId,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
      });
      widget.onCommentAdded();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _errorText(Object error) {
    return error is ApiException ? error.message : 'تعذر تنفيذ العملية.';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'التعليقات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('ماكو تعليقات بعد.'))
                        : ListView.separated(
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    child: Text(
                                      comment.author.displayName.isEmpty
                                          ? '?'
                                          : comment.author.displayName.characters.first,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.author.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(comment.body),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تعليقاً...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'إرسال التعليق',
                    onPressed: _sending ? null : _sendComment,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedStatus extends StatelessWidget {
  const _FeedStatus({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
