// lib/features/portfolio/screens/portfolio_screen.dart
//
// UPDATED: Each project card shows a gallery icon with image count.
// Tapping icon opens full-screen ImageGalleryViewer.
// Detail sheet has swipeable image strip + thumbnail row.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/tokilo_motion.dart';
import '../../../core/widgets/image_gallery_viewer.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, List<String>> _extraImages = {};
  bool _loading = true;
  String _selectedFilter = 'All';
  List<String> _filters = ['All'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final showcaseData = await _supabase
          .from('project_showcase')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      final items = List<Map<String, dynamic>>.from(showcaseData);

      final imgData = await _supabase
          .from('project_images')
          .select()
          .filter('showcase_id', 'not.is', null)
          .order('sort_order');
      final Map<String, List<String>> imgMap = {};
      for (final row in (imgData as List)) {
        final sid = row['showcase_id']?.toString();
        if (sid != null)
          imgMap.putIfAbsent(sid, () => []).add(row['image_url'] as String);
      }

      final tags = <String>{'All'};
      for (final item in items) {
        final sub = item['subtitle'] as String?;
        if (sub != null && sub.isNotEmpty) {
          for (final part in sub.split(RegExp(r'[·•,]'))) {
            final t = part.trim();
            if (t.isNotEmpty) tags.add(t);
          }
        }
      }

      if (mounted) {
        setState(() {
          _all = items;
          _filtered = items;
          _extraImages = imgMap;
          _filters = tags.toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _allImages(Map<String, dynamic> item) {
    final extra = _extraImages[item['id']?.toString() ?? ''] ?? [];
    final cover = item['image_url'] as String?;
    if (cover != null && cover.isNotEmpty)
      return [cover, ...extra.where((u) => u != cover)];
    return extra;
  }

  void _applyFilter(String f) {
    setState(() {
      _selectedFilter = f;
      _filtered = f == 'All'
          ? _all
          : _all
                .where((i) => (i['subtitle'] as String? ?? '').contains(f))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight:
                172 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 100,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            title: const Text('Our work'),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 76, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ideas, brought to life.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_all.length} published projects',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (!_loading && _filters.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final active = _selectedFilter == f;
                    return GestureDetector(
                      onTap: () => _applyFilter(f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AnimatedCard(
                    key: ValueKey(_filtered[i]['id']),
                    item: _filtered[i],
                    allImages: _allImages(_filtered[i]),
                    index: i,
                  ),
                  childCount: _filtered.length,
                ),
              ),
            ),

          if (!_loading && _filtered.isNotEmpty)
            SliverToBoxAdapter(child: _buildCTA(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_library_outlined,
          size: 72,
          color: AppColors.primary.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        const Text(
          'No projects yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check back soon',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildCTA(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF03404E), Color(0xFF06768D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Have a project in mind?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Let\'s build something great together.',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.go('/portal'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start a Project',
                  style: TextStyle(
                    color: Color(0xFF03404E),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF03404E),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({
    required super.key,
    required this.item,
    required this.allImages,
    required this.index,
  });
  final Map<String, dynamic> item;
  final List<String> allImages;
  final int index;
  @override
  Widget build(BuildContext context) => ScrollReveal(
    child: _ShowcaseCard(item: item, allImages: allImages),
  );
}

class _ShowcaseCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<String> allImages;
  const _ShowcaseCard({required this.item, required this.allImages});
  @override
  State<_ShowcaseCard> createState() => _ShowcaseCardState();
}

class _ShowcaseCardState extends State<_ShowcaseCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final title = widget.item['title'] ?? 'Project';
    final subtitle = widget.item['subtitle'] as String?;
    final images = widget.allImages;
    final cover = images.isNotEmpty ? images.first : null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DetailSheet(item: widget.item, allImages: images),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _buildCover(cover),
                    if (images.isNotEmpty)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => ImageGalleryViewer.show(
                            context,
                            images: images,
                            initialIndex: 0,
                            title: title,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${images.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  color: Colors.white70,
                                  size: 11,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildTags(subtitle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String? url) {
    const h = 220.0;
    if (url == null || url.isEmpty)
      return Container(
        height: h,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03404E), Color(0xFF06768D)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.work_rounded, color: Colors.white24, size: 56),
        ),
      );
    return SizedBox(
      height: h,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF03404E), Color(0xFF06768D)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTags(String subtitle) {
    final tags = subtitle
        .split(RegExp(r'[·•,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final colors = [
      AppColors.primary,
      AppColors.accent,
      const Color(0xFF8B5CF6),
      AppColors.success,
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            e.value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DetailSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<String> allImages;
  const _DetailSheet({required this.item, required this.allImages});
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  int _active = 0;
  late PageController _pageCtrl;
  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title'] ?? 'Project';
    final subtitle = widget.item['subtitle'] as String?;
    final images = widget.allImages;
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: sc,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Image slideshow
            if (images.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 240,
                        child: PageView.builder(
                          controller: _pageCtrl,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _active = i),
                          itemBuilder: (_, i) => Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.border,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.textHint,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Fullscreen btn
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => ImageGalleryViewer.show(
                          context,
                          images: images,
                          initialIndex: _active,
                          title: title,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Dots
                    if (images.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => GestureDetector(
                              onTap: () => _pageCtrl.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _active == i ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _active == i
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Thumbnail strip
              if (images.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: images.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _pageCtrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _active == i
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(images[i], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    _SheetTags(subtitle: subtitle),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/portal');
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF03404E), Color(0xFF06768D)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Start a Similar Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'Back to Showcase',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTags extends StatelessWidget {
  final String subtitle;
  const _SheetTags({required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final tags = subtitle
        .split(RegExp(r'[·•,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final colors = [
      AppColors.primary,
      AppColors.accent,
      const Color(0xFF8B5CF6),
      AppColors.success,
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            e.value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
