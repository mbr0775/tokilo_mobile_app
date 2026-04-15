// lib/features/home/screens/components/home_products_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/cart/cart_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// In-memory favourites store
// ─────────────────────────────────────────────────────────────────────────────
class _FavStore extends ChangeNotifier {
  static final _FavStore instance = _FavStore._();
  _FavStore._();

  final Map<String, int> _counts = {};
  final Set<String> _liked = {};

  int count(String id) => _counts[id] ?? 0;
  bool liked(String id) => _liked.contains(id);

  void toggle(String id) {
    if (_liked.contains(id)) {
      _liked.remove(id);
      _counts[id] = (_counts[id] ?? 1) - 1;
    } else {
      _liked.add(id);
      _counts[id] = (_counts[id] ?? 0) + 1;
    }
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SECTION WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class HomeProductsSection extends StatefulWidget {
  const HomeProductsSection({super.key});

  @override
  State<HomeProductsSection> createState() => _HomeProductsSectionState();
}

class _HomeProductsSectionState extends State<HomeProductsSection>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  late AnimationController _shimmerCtrl;

  static const List<String> _allCategories = [
    'All', 'Surveillance', 'Networking', 'Cabling',
    'Hardware', 'Power', 'Accessories',
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadProducts();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final data = await _supabase
          .from('it_products')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _allProducts = List<Map<String, dynamic>>.from(data);
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filtered = _selectedCategory == 'All'
        ? List.from(_allProducts)
        : _allProducts
            .where((p) => p['category'] == _selectedCategory)
            .toList();
  }

  void _selectCategory(String cat) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = cat;
      _applyFilter();
    });
  }

  Color _imageBg(String? cat) {
    switch (cat) {
      case 'Surveillance': return const Color(0xFFEDF2FF);
      case 'Networking':   return const Color(0xFFEDFDF8);
      case 'Cabling':      return const Color(0xFFFFF4ED);
      case 'Hardware':     return const Color(0xFFF3F0FF);
      case 'Power':        return const Color(0xFFFFFBEB);
      case 'Accessories':  return const Color(0xFFFFF0F6);
      default:             return const Color(0xFFEFF9FB);
    }
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'Surveillance': return Icons.videocam_rounded;
      case 'Networking':   return Icons.device_hub_rounded;
      case 'Cabling':      return Icons.cable_rounded;
      case 'Hardware':     return Icons.dns_rounded;
      case 'Power':        return Icons.battery_charging_full_rounded;
      case 'Accessories':  return Icons.devices_other_rounded;
      default:             return Icons.devices_rounded;
    }
  }

  Color _iconColor(String? cat) {
    switch (cat) {
      case 'Surveillance': return const Color(0xFF3B82F6);
      case 'Networking':   return const Color(0xFF10B981);
      case 'Cabling':      return const Color(0xFFF97316);
      case 'Hardware':     return const Color(0xFF8B5CF6);
      case 'Power':        return const Color(0xFFF59E0B);
      case 'Accessories':  return const Color(0xFFEC4899);
      default:             return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category Pills ────────────────────────────────────────────
        const SizedBox(height: 24),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _allCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _allCategories[i];
              return _CategoryPill(
                label:    cat,
                selected: cat == _selectedCategory,
                onTap:    () => _selectCategory(cat),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // ── Header ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Arrivals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '${_filtered.length} products',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/marketplace'),
                child: const Row(
                  children: [
                    Text('See All',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Product list ──────────────────────────────────────────────
        if (_isLoading)
          _ShimmerRow(controller: _shimmerCtrl)
        else if (_filtered.isEmpty)
          const _EmptyState()
        else
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _ProductCard(
                product:      _filtered[i],
                imageBg:      _imageBg(_filtered[i]['category'] as String?),
                fallbackIcon: _categoryIcon(_filtered[i]['category'] as String?),
                iconColor:    _iconColor(_filtered[i]['category'] as String?),
                delay:        Duration(milliseconds: i * 60),
              ),
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY PILL
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryPill extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryPill> createState() => _CategoryPillState();
}

class _CategoryPillState extends State<_CategoryPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.91)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => _ctrl.forward(),
      onTapUp:    (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF0F172A)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(widget.selected ? 0.18 : 0.04),
                blurRadius: widget.selected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.selected
                  ? Colors.white
                  : const Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final Color    imageBg;
  final IconData fallbackIcon;
  final Color    iconColor;
  final Duration delay;

  const _ProductCard({
    required this.product,
    required this.imageBg,
    required this.fallbackIcon,
    required this.iconColor,
    required this.delay,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _scale = Tween(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)));
    _slide = Tween(begin: const Offset(0.1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _id => widget.product['id']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final imageUrl    = widget.product['image_url']   as String?;
    final price       = widget.product['price']       as String?;
    final name        = widget.product['name']        as String? ?? '';
    final description = widget.product['description'] as String?;
    final inStock     = widget.product['in_stock']    as bool? ?? true;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 185,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF2), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.black.withOpacity(0.03),
                    blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image zone ──────────────────────────────────────
                  Stack(
                    children: [
                      Container(
                        height: 148,
                        width: double.infinity,
                        color: widget.imageBg,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 120, height: 120,
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 120, height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallback(),
                                    )
                                  : _fallback(),
                            ),
                          ),
                        ),
                      ),
                      // Heart button
                      Positioned(
                        top: 10, right: 10,
                        child: _HeartButton(
                            productId: _id, color: widget.iconColor),
                      ),
                      // Out of stock ribbon
                      if (!inStock)
                        Positioned(
                          top: 14, left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              borderRadius: BorderRadius.only(
                                topRight:    Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: const Text('Out of Stock',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),

                  // ── Info zone ───────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (description != null &&
                                  description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(description,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF94A3B8),
                                        height: 1.4,
                                        fontWeight: FontWeight.w400),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  (price != null && price.isNotEmpty)
                                      ? price
                                      : 'Get Quote',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: (price != null &&
                                            price.isNotEmpty)
                                        ? const Color(0xFF0F172A)
                                        : AppColors.primary,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _AddButton(
                                enabled: inStock,
                                product: widget.product,
                              ),
                            ],
                          ),
                        ],
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

  Widget _fallback() => Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: widget.iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(widget.fallbackIcon, color: widget.iconColor, size: 32),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HEART BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _HeartButton extends StatefulWidget {
  final String productId;
  final Color  color;
  const _HeartButton({required this.productId, required this.color});

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pop = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _FavStore.instance.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _FavStore.instance.removeListener(_rebuild);
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    _FavStore.instance.toggle(widget.productId);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final liked = _FavStore.instance.liked(widget.productId);
    final count = _FavStore.instance.count(widget.productId);

    return GestureDetector(
      onTap: _toggle,
      child: ScaleTransition(
        scale: _pop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: liked
                ? const Color(0xFFFF3B5C).withOpacity(0.10)
                : Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: liked
                  ? const Color(0xFFFF3B5C).withOpacity(0.35)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 14,
                color: liked
                    ? const Color(0xFFFF3B5C)
                    : const Color(0xFF94A3B8),
              ),
              if (count > 0) ...[
                const SizedBox(width: 3),
                Text('$count',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: liked
                            ? const Color(0xFFFF3B5C)
                            : const Color(0xFF94A3B8))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD BUTTON  ← FIXED: captures router & messenger before async gap
// ─────────────────────────────────────────────────────────────────────────────
class _AddButton extends StatefulWidget {
  final bool enabled;
  final Map<String, dynamic> product;

  const _AddButton({
    required this.enabled,
    required this.product,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.86)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    CartStore.instance.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    CartStore.instance.removeListener(_rebuild);
    _ctrl.dispose();
    super.dispose();
  }

  bool get _inCart =>
      CartStore.instance.contains(widget.product['id']?.toString() ?? '');

  void _tap() async {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();

    // ✅ CRITICAL FIX: capture router & messenger BEFORE any await
    // After await, the context may be detached from the widget tree
    final router    = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _ctrl.forward();
    await _ctrl.reverse();

    // If already in cart → navigate to cart screen
    if (_inCart) {
      router.push('/cart');
      return;
    }

    // Add to cart
    CartStore.instance.add(widget.product);

    // Show snackbar — uses pre-captured messenger & router (safe after await)
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Added to cart!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () => router.push('/cart'), // ✅ uses captured router
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inCart = _inCart;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: !widget.enabled
                ? const Color(0xFFE2E8F0)
                : inCart
                    ? const Color(0xFF10B981)
                    : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(11),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: (inCart
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0F172A))
                          .withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Icon(
            inCart
                ? Icons.shopping_cart_rounded
                : Icons.add_rounded,
            color: widget.enabled
                ? Colors.white
                : const Color(0xFFCBD5E1),
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerRow extends StatelessWidget {
  final AnimationController controller;
  const _ShimmerRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final grad = LinearGradient(
            colors: const [
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
              Color(0xFFF1F5F9),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-1.5 + controller.value * 3, 0),
            end:   Alignment(-0.5 + controller.value * 3, 0),
          );
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) => Container(
              width: 185,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: grad,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.devices_outlined,
                  size: 28, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text('No products in this category',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}