import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_user.dart';
import '../../feed/domain/feed_post.dart';
import '../data/reels_repository.dart';
import '../domain/reel.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({
    super.key,
    required this.user,
    required this.accessToken,
    required this.repository,
    required this.onSaveInterests,
  });

  final AuthUser user;
  final String accessToken;
  final ReelsRepository repository;
  final Future<bool> Function(List<String> interests) onSaveInterests;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  static const _categories = <_InterestCategory>[
    _InterestCategory('sports', 'رياضة', Icons.sports_soccer, 'مباريات وأخبار الرياضة'),
    _InterestCategory('gaming', 'ألعاب', Icons.sports_esports, 'ألعاب ومجتمعات اللاعبين'),
    _InterestCategory('entertainment', 'ترفيه', Icons.movie_outlined, 'محتوى ترفيهي'),
    _InterestCategory('religion', 'ديني', Icons.auto_stories_outlined, 'محتوى ديني ومعرفي'),
    _InterestCategory('education', 'تعليم', Icons.school_outlined, 'تعلم ومهارات'),
    _InterestCategory('design', 'تصاميم', Icons.palette_outlined, 'تصميم وإبداع'),
    _InterestCategory('technology', 'تقنية', Icons.devices_outlined, 'تقنية وابتكارات'),
    _InterestCategory('news', 'أخبار', Icons.newspaper_outlined, 'أخبار ومعلومات'),
    _InterestCategory('fashion', 'أزياء', Icons.checkroom_outlined, 'أزياء وأفكار'),
    _InterestCategory('cooking', 'طبخ', Icons.restaurant_outlined, 'وصفات وأكل'),
    _InterestCategory('travel', 'سفر', Icons.flight_takeoff_outlined, 'أماكن وتجارب'),
    _InterestCategory('science', 'علوم', Icons.science_outlined, 'علوم واكتشافات'),
    _InterestCategory('comedy', 'كوميديا', Icons.mood_outlined, 'مواقف مضحكة'),
    _InterestCategory('art', 'فنون', Icons.brush_outlined, 'فن ومواهب'),
    _InterestCategory('global_trends', 'ترندات العالم', Icons.public_outlined, 'مواضيع رائجة من مصادر موثوقة'),
  ];

  final ImagePicker _picker = ImagePicker();
  final Set<String> _selectedInterests = <String>{};
  List<Reel> _reels = const [];
  String? _selectedCategory;
  String? _error;
  bool _loading = true;
  bool _uploadEnabled = false;
  bool _uploading = false;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _selectedInterests.addAll(widget.user.interests);
    unawaited(_loadReels());
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.interests != widget.user.interests) {
      _selectedInterests
        ..clear()
        ..addAll(widget.user.interests);
    }
  }

  Future<void> _loadReels({String? category, bool updateCategory = false}) async {
    if (mounted) {
      setState(() {
        if (updateCategory) _selectedCategory = category;
        _loading = true;
        _error = null;
      });
    }

    try {
      final feed = await widget.repository.loadReels(
        accessToken: widget.accessToken,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _reels = feed.reels;
        _uploadEnabled = feed.uploadEnabled;
        _loading = false;
        _error = null;
        _activePage = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;
    return 'تعذر تحميل الريلز. تحقق من اتصالك وحاول مرة ثانية.';
  }

  Future<void> _editInterests() async {
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InterestChooserSheet(
        initialSelection: _selectedInterests,
        categories: _categories,
      ),
    );
    if (updated == null || !mounted) return;

    final saved = await widget.onSaveInterests(updated);
    if (!mounted || !saved) return;
    setState(() {
      _selectedInterests
        ..clear()
        ..addAll(updated);
    });
    await _loadReels();
  }

  Future<void> _selectAndUploadVideo() async {
    if (_uploading) return;
    if (!_uploadEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رفع الفيديو غير مفعّل على الخادم بعد. يلزم إعداد تخزين الفيديو أولاً.'),
        ),
      );
      return;
    }

    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (video == null || !mounted) return;

      final details = await showModalBottomSheet<_ReelDraft>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _UploadReelSheet(
          initialCategory: widget.user.interests.isNotEmpty
              ? widget.user.interests.first
              : 'entertainment',
          categories: _categories,
        ),
      );
      if (details == null || !mounted) return;

      setState(() => _uploading = true);
      final created = await widget.repository.uploadReel(
        accessToken: widget.accessToken,
        video: video,
        category: details.category,
        caption: details.caption,
      );
      if (!mounted) return;
      setState(() {
        _selectedCategory = details.category;
        _reels = [created, ..._reels.where((reel) => reel.id != created.id)];
        _uploadEnabled = true;
        _activePage = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر الريل بنجاح.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'ريلز فايكو',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ),
              IconButton(
                tooltip: 'اختيار الاهتمامات',
                onPressed: _editInterests,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: 'نشر ريل',
                onPressed: _uploading ? null : _selectAndUploadVideo,
                icon: _uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            key: const ValueKey('reel-category-list'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: FilterChip(
                  label: const Text('لك'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _loadReels(updateCategory: true),
                ),
              ),
              for (final category in _categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Tooltip(
                    message: category.description,
                    child: FilterChip(
                      key: ValueKey('reel-category-${category.id}'),
                      label: Text(category.label),
                      selected: _selectedCategory == category.id,
                      onSelected: (_) => _loadReels(
                        category: category.id,
                        updateCategory: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ReelMessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'ما قدرنا نحمل الريلز',
                      description: _error!,
                      actionLabel: 'إعادة المحاولة',
                      onAction: () => unawaited(_loadReels()),
                    )
                  : _reels.isEmpty
                      ? _ReelMessageState(
                          icon: Icons.play_circle_outline,
                          title: _uploadEnabled
                              ? 'خلّيك أول من ينشر ريل'
                              : 'الريلز تحتاج إعداد مخزن الفيديو',
                          description: _uploadEnabled
                              ? 'ماكو فيديوهات بهذا القسم بعد. اختار فيديو MP4 من جهازك وانشره حتى يشوفه غيرك.'
                              : 'التصنيفات صارت جاهزة، لكن الرفع والتشغيل ما يشتغلان إلا بعد ربط مخزن فيديو آمن بالخادم.',
                          actionLabel: _uploadEnabled ? 'اختيار فيديو' : 'ليش ما يشتغل الرفع؟',
                          onAction: _uploadEnabled
                              ? _selectAndUploadVideo
                              : () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('يلزم ضبط بيانات مخزن الفيديو على الخادم قبل الرفع.'),
                                    ),
                                  ),
                        )
                      : PageView.builder(
                          key: const ValueKey('reel-page-view'),
                          scrollDirection: Axis.vertical,
                          itemCount: _reels.length,
                          onPageChanged: (index) => setState(() => _activePage = index),
                          itemBuilder: (context, index) => _ReelVideoPage(
                            reel: _reels[index],
                            active: index == _activePage,
                          ),
                        ),
        ),
        if (!_uploadEnabled && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.onSurfaceVariant, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ميزة رفع الفيديو بانتظار إعداد التخزين الخارجي.',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReelVideoPage extends StatefulWidget {
  const _ReelVideoPage({required this.reel, required this.active});

  final Reel reel;
  final bool active;

  @override
  State<_ReelVideoPage> createState() => _ReelVideoPageState();
}

class _ReelVideoPageState extends State<_ReelVideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.videoUrl != widget.reel.videoUrl) {
      final oldController = _controller;
      _controller = null;
      if (oldController != null) unawaited(oldController.dispose());
      _failed = false;
      unawaited(_initialize());
    } else if (oldWidget.active != widget.active) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        if (widget.active) {
          unawaited(controller.play());
        } else {
          unawaited(controller.pause());
        }
      }
    }
  }

  Future<void> _initialize() async {
    final url = widget.reel.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {});
      if (widget.active) await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final controller = _controller;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_failed && controller != null && controller.value.isInitialized)
            GestureDetector(
              onTap: _togglePlayback,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _failed ? Icons.video_library_outlined : Icons.hourglass_top,
                    color: Colors.white70,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _failed ? 'الفيديو غير متاح حالياً' : 'جاري تحميل الفيديو...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          if (_showControls && controller != null && controller.value.isInitialized)
            Positioned(
              top: 14,
              left: 14,
              child: IconButton.filledTonal(
                onPressed: _togglePlayback,
                tooltip: controller.value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '@${reel.author.username}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(postCategoryLabel(reel.category)),
                          labelStyle: TextStyle(color: colors.onSurface),
                        ),
                      ],
                    ),
                    if (reel.caption.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelMessageState extends StatelessWidget {
  const _ReelMessageState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestChooserSheet extends StatefulWidget {
  const _InterestChooserSheet({
    required this.initialSelection,
    required this.categories,
  });

  final Set<String> initialSelection;
  final List<_InterestCategory> categories;

  @override
  State<_InterestChooserSheet> createState() => _InterestChooserSheetState();
}

class _InterestChooserSheetState extends State<_InterestChooserSheet> {
  late final Set<String> _selection = widget.initialSelection.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختار اهتماماتك',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('فايكو يرتّب المواضيع اللي تختارها قبل باقي التصنيفات.'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in widget.categories)
                    FilterChip(
                      key: ValueKey('edit-interest-${category.id}'),
                      avatar: Icon(category.icon, size: 17),
                      label: Text(category.label),
                      selected: _selection.contains(category.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selection.add(category.id);
                          } else {
                            _selection.remove(category.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selection.toList()),
                  child: const Text('حفظ الاهتمامات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadReelSheet extends StatefulWidget {
  const _UploadReelSheet({
    required this.initialCategory,
    required this.categories,
  });

  final String initialCategory;
  final List<_InterestCategory> categories;

  @override
  State<_UploadReelSheet> createState() => _UploadReelSheetState();
}

class _UploadReelSheetState extends State<_UploadReelSheet> {
  final TextEditingController _captionController = TextEditingController();
  late String _category = widget.initialCategory;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الريل',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in widget.categories)
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'وصف الريل (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _ReelDraft(
                    category: _category,
                    caption: _captionController.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('رفع ونشر'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'MP4 فقط، مدة أقصاها 3 دقائق وحجم أقصاه 150 ميگابايت.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelDraft {
  const _ReelDraft({required this.category, required this.caption});

  final String category;
  final String caption;
}

class _InterestCategory {
  const _InterestCategory(this.id, this.label, this.icon, this.description);

  final String id;
  final String label;
  final IconData icon;
  final String description;
}
