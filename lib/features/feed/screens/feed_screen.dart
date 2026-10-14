// lib/features/feed/screens/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../admin/navigation/admin_router.dart';
import '../../../core/widgets/tokilo_motion.dart';
import '../../../core/widgets/studio_ui.dart';
import '../models/feed_post_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  final List<FeedPostModel> _posts = [];
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedPostIds = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 0;
  static const int _pageSize = 8;

  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Projects',
    'News',
    'Offers',
    'Updates',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialFeed();

    _scrollController.addListener(() {
      final position = _scrollController.position;

      if (position.pixels >= position.maxScrollExtent - 320 &&
          !_isLoadingMore &&
          !_isLoading &&
          _hasMore) {
        _loadMoreFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<FeedPostModel> get _visiblePosts {
    if (_selectedFilter == 'All') return _posts;

    return _posts.where((post) {
      switch (_selectedFilter) {
        case 'Projects':
          return post.type == FeedPostType.project;
        case 'News':
          return post.type == FeedPostType.news;
        case 'Offers':
          return post.type == FeedPostType.offer;
        case 'Updates':
          return post.type == FeedPostType.feature;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _loadInitialFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
      _posts.clear();
      _likeCounts.clear();
      _likedPostIds.clear();
    });

    try {
      final newPosts = await _fetchFeedPage(page: 0);
      await _loadLikeInfoForPosts(newPosts);

      if (!mounted) return;

      setState(() {
        _posts.addAll(newPosts);
        _hasMore = newPosts.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load updates. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreFeed() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final newPosts = await _fetchFeedPage(page: nextPage);
      await _loadLikeInfoForPosts(newPosts);

      if (!mounted) return;

      setState(() {
        _page = nextPage;
        _posts.addAll(newPosts);
        _hasMore = newPosts.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<FeedPostModel>> _fetchFeedPage({required int page}) async {
    final int from = page * _pageSize;
    final int to = from + _pageSize - 1;

    // Independent content sources load together so the feed appears sooner.
    final data = await Future.wait<dynamic>([
      for (final table in [
        'project_showcase',
        'home_banners',
        'home_promos',
        'home_features',
      ])
        _supabase
            .from(table)
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .range(from, to),
    ]);
    final merged = <FeedPostModel>[
      ...List<Map<String, dynamic>>.from(
        data[0],
      ).map(FeedPostModel.fromProjectShowcase),
      ...List<Map<String, dynamic>>.from(
        data[1],
      ).map(FeedPostModel.fromHomeBanner),
      ...List<Map<String, dynamic>>.from(
        data[2],
      ).map(FeedPostModel.fromHomePromo),
      ...List<Map<String, dynamic>>.from(
        data[3],
      ).map(FeedPostModel.fromHomeFeature),
    ];

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return merged.take(_pageSize).toList();
  }

  Future<void> _loadLikeInfoForPosts(List<FeedPostModel> posts) async {
    final user = _supabase.auth.currentUser;
    if (user == null || posts.isEmpty) return;

    final postIds = posts.map((p) => p.id).toList();

    try {
      final data = await _supabase.rpc(
        'tokilo_feed_like_counts',
        params: {'p_post_ids': postIds},
      );
      final rows = List<Map<String, dynamic>>.from(data);
      final counts = <String, int>{};
      final likedByMe = <String>{};
      for (final row in rows) {
        final postId = row['post_id']?.toString();
        if (postId == null) continue;
        counts[postId] = (row['like_count'] as num?)?.toInt() ?? 0;
        if (row['is_liked'] == true) likedByMe.add(postId);
      }

      if (!mounted) return;

      setState(() {
        for (final postId in postIds) {
          _likeCounts[postId] = counts[postId] ?? 0;
        }
        _likedPostIds.removeAll(postIds);
        _likedPostIds.addAll(likedByMe);
      });
    } catch (_) {
      // Feed should still work even if likes fail.
    }
  }

  Future<void> _toggleLike(FeedPostModel post) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final postId = post.id;
    final isLiked = _likedPostIds.contains(postId);

    setState(() {
      if (isLiked) {
        _likedPostIds.remove(postId);
        _likeCounts[postId] = ((_likeCounts[postId] ?? 1) - 1).clamp(0, 999999);
      } else {
        _likedPostIds.add(postId);
        _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
      }
    });

    try {
      if (isLiked) {
        await _supabase
            .from('feed_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        await _supabase.from('feed_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (isLiked) {
          _likedPostIds.add(postId);
          _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
        } else {
          _likedPostIds.remove(postId);
          _likeCounts[postId] = ((_likeCounts[postId] ?? 1) - 1).clamp(
            0,
            999999,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Like update failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    await _loadInitialFeed();
  }

  void _openChat() {
    context.push(isAdminUser() ? '/admin/messages' : '/chat');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const _FeedHeader(),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From the studio',
                      style: TextStyle(
                        color: StudioColors.ink,
                        fontSize: 27,
                        letterSpacing: -.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Fresh work, new ideas and what’s next.',
                      style: TextStyle(fontSize: 12, color: StudioColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeader(
                filters: _filters,
                selected: _selectedFilter,
                height:
                    54 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 16,
                onChanged: (value) => setState(() => _selectedFilter = value),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(message: _error!, onRetry: _loadInitialFeed),
              )
            else if (_visiblePosts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFeedState(),
              )
            else
              SliverList.builder(
                itemCount: _visiblePosts.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _visiblePosts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final post = _visiblePosts[index];

                  return ScrollReveal(
                    key: ValueKey(post.id),
                    child: FeedPostCard(
                      post: post,
                      likeCount: _likeCounts[post.id] ?? 0,
                      isLiked: _likedPostIds.contains(post.id),
                      onLike: () => _toggleLike(post),
                      onMessage: _openChat,
                    ),
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();
  @override
  Widget build(BuildContext context) => const SliverAppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    pinned: true,
    automaticallyImplyLeading: false,
    toolbarHeight: 64,
    titleSpacing: 20,
    title: StudioHeader(),
  );
}

class _FilterHeader extends SliverPersistentHeaderDelegate {
  _FilterHeader({
    required this.filters,
    required this.selected,
    required this.onChanged,
    required this.height,
  });
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onChanged;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  bool shouldRebuild(covariant _FilterHeader oldDelegate) =>
      selected != oldDelegate.selected || height != oldDelegate.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Colors.white,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudioColors.line)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 24),
        itemBuilder: (context, index) => Semantics(
          selected: selected == filters[index],
          button: true,
          child: InkWell(
            onTap: () => onChanged(filters[index]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      filters[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected == filters[index]
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected == filters[index]
                            ? StudioColors.ink
                            : StudioColors.muted,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  height: 3,
                  width: selected == filters[index] ? 25 : 0,
                  decoration: const BoxDecoration(
                    color: StudioColors.ink,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class FeedPostCard extends StatelessWidget {
  final FeedPostModel post;
  final int likeCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onMessage;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.likeCount,
    required this.isLiked,
    required this.onLike,
    required this.onMessage,
  });

  Color get _typeColor {
    switch (post.type) {
      case FeedPostType.project:
        return AppColors.primary;
      case FeedPostType.news:
        return const Color(0xFF3B82F6);
      case FeedPostType.offer:
        return AppColors.warning;
      case FeedPostType.feature:
        return AppColors.success;
    }
  }

  IconData get _typeIcon {
    switch (post.type) {
      case FeedPostType.project:
        return Icons.work_rounded;
      case FeedPostType.news:
        return Icons.newspaper_rounded;
      case FeedPostType.offer:
        return Icons.local_offer_rounded;
      case FeedPostType.feature:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;
    final hasImage = post.imageUrl?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: StudioColors.ink,
                child: Text(
                  't.',
                  style: TextStyle(
                    fontSize: 23,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tokilo Technologies',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: StudioColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeAgo(post.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: StudioColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      post.typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasImage) ...[
            StudioProjectMedia(
              title: post.title,
              url: post.imageUrl,
              category: post.category ?? post.subtitle,
              height: 226,
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              height: 3,
              width: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.2,
              letterSpacing: -.6,
              fontWeight: FontWeight.w700,
              color: StudioColors.ink,
            ),
          ),
          if (post.subtitle?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              post.subtitle!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: StudioColors.muted,
              ),
            ),
          ],
          if ((post.body?.isNotEmpty ?? false) &&
              post.body != post.subtitle) ...[
            const SizedBox(height: 8),
            _ExpandableCopy(key: ValueKey('copy_${post.id}'), text: post.body!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: onLike,
                style: TextButton.styleFrom(
                  foregroundColor: isLiked ? AppColors.error : StudioColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(48, 48),
                ),
                icon: AnimatedScale(
                  scale: isLiked ? 1.12 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 22,
                  ),
                ),
                label: Text(
                  likeCount == 0 ? 'Like' : '$likeCount',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Message Tokilo',
                onPressed: onMessage,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: StudioColors.ink,
                  size: 21,
                ),
              ),
              if ((post.buttonLabel?.isNotEmpty ?? false) &&
                  (post.buttonRoute?.startsWith('/') ?? false))
                TextButton.icon(
                  onPressed: () => context.push(post.buttonRoute!),
                  style: TextButton.styleFrom(
                    foregroundColor: StudioColors.ink,
                    backgroundColor: StudioColors.lime,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 42),
                  ),
                  label: Text(
                    post.buttonLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.north_east_rounded, size: 15),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: StudioColors.line),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ExpandableCopy extends StatefulWidget {
  const _ExpandableCopy({super.key, required this.text});
  final String text;
  @override
  State<_ExpandableCopy> createState() => _ExpandableCopyState();
}

class _ExpandableCopyState extends State<_ExpandableCopy> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        alignment: Alignment.topLeft,
        child: Text(
          widget.text,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: StudioColors.muted,
          ),
        ),
      ),
      if (widget.text.length > 150)
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            foregroundColor: StudioColors.ink,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            _expanded ? 'Show less' : 'Read more',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
    ],
  );
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dynamic_feed_rounded,
              color: AppColors.primary.withOpacity(0.25),
              size: 76,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When Tokilo uploads projects, news or offers, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.error,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
