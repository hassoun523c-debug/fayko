import 'package:flutter/material.dart';

import '../../auth/domain/auth_user.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({
    super.key,
    required this.user,
    required this.onSaveInterests,
  });

  final AuthUser user;
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

  late final Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.user.interests.toSet();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSaveInterests(_categories
          .where((category) => _selected.contains(category.id))
          .map((category) => category.id)
          .toList(growable: false));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.play_circle_fill, size: 32, color: colors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ذوقك في فايكو',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'اختار المواضيع اللي تحبها. اهتماماتك تنحفظ بحسابك ونستخدمها لتطوير ترتيب المحتوى لاحقاً.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _categories)
                    FilterChip(
                      key: ValueKey('interest-\${category.id}'),
                      avatar: Icon(category.icon, size: 18),
                      label: Text(category.label),
                      selected: _selected.contains(category.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selected.add(category.id);
                          } else {
                            _selected.remove(category.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ اهتماماتي (\${_selected.length})'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.construction_outlined),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تشغيل الريلز قيد التطوير',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'اختيار التصنيفات وحفظها جاهز في هذه المرحلة، لكن رفع الفيديوهات وتشغيلها وتوصية المقاطع الحقيقية ما زالت تحتاج إكمال وربط تخزين وسائط. ما نعرض مقاطع وهمية على أنها محتوى حقيقي.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InterestCategory {
  const _InterestCategory(this.id, this.label, this.icon, this.description);

  final String id;
  final String label;
  final IconData icon;
  final String description;
}
