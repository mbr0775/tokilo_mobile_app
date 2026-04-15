// lib/features/home/screens/components/home_promos_section.dart
//
// Modern redesign: horizontal scroll cards, auto-scroll, page dots, animations.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';

class HomePromosSection extends StatefulWidget {
  const HomePromosSection({super.key});

  @override
  State<HomePromosSection> createState() => _HomePromosSectionState();
}

class _HomePromosSectionState extends State<HomePromosSection>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _pageController = PageController(viewportFraction: 0.88);
  List<_PromoCard> _promos = [];
  bool _isLoading = true;
  int _currentPage = 0;
  Timer? _autoTimer;

  late AnimationController _shimmerCtrl;

  // ── Default fallback ─────────────────────────────────────────────────────
  static final _defaultPromos = [
    _PromoCard(
      title: 'Special Promo!',
      subtitle: 'Contact us today for exclusive offers and discounts.',
      buttonLabel: 'Contact Us',
      bgColors: [const Color(0xFF06768D), const Color(0xFF0A9BBF)],
      iconData: Icons.local_offer_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _load();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _startAutoScroll(int count) {
    if (count <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('home_promos')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final raw = List<Map<String, dynamic>>.from(data);

      // Deduplicate by id
      final seen = <dynamic>{};
      final unique = raw.where((p) => seen.add(p['id'])).toList();

      // Batch-fetch linked images
      final serviceIds = unique
          .map((p) => p['service_id'])
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      final productIds = unique
          .map((p) => p['product_id'])
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> imageMap = {};
      final Map<String, String> nameMap = {};

      if (serviceIds.isNotEmpty) {
        final rows = await _supabase
            .from('services')
            .select('id, title, image_url')
            .inFilter('id', serviceIds);
        for (final r in rows) {
          final id = r['id'].toString();
          if ((r['image_url'] ?? '').isNotEmpty) imageMap['s_$id'] = r['image_url'];
          if ((r['title'] ?? '').isNotEmpty) nameMap['s_$id'] = r['title'];
        }
      }
      if (productIds.isNotEmpty) {
        final rows = await _supabase
            .from('it_products')
            .select('id, name, image_url')
            .inFilter('id', productIds);
        for (final r in rows) {
          final id = r['id'].toString();
          if ((r['image_url'] ?? '').isNotEmpty) imageMap['p_$id'] = r['image_url'];
          if ((r['name'] ?? '').isNotEmpty) nameMap['p_$id'] = r['name'];
        }
      }

      final cards = unique.map((p) {
        String? imageUrl;
        String? linkedName;
        final sid = (p['service_id'] ?? '').toString();
        final pid = (p['product_id'] ?? '').toString();
        if (sid.isNotEmpty) {
          imageUrl = imageMap['s_$sid'];
          linkedName = nameMap['s_$sid'];
        } else if (pid.isNotEmpty) {
          imageUrl = imageMap['p_$pid'];
          linkedName = nameMap['p_$pid'];
        }
        if (imageUrl == null && (p['image_url'] ?? '').isNotEmpty) {
          imageUrl = p['image_url'] as String;
        }

        final bg = _parseColor(p['bg_color'] as String?);
        return _PromoCard(
          title: linkedName ?? (p['title'] as String? ?? ''),
          subtitle: p['subtitle'] as String? ?? '',
          buttonLabel: p['button_label'] as String? ?? '',
          bgColors: _gradientForColor(bg),
          iconData: _iconForType(p['promo_type'] as String?),
          imageUrl: imageUrl,
          accentColor: bg,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _promos = cards.isEmpty ? _defaultPromos : cards;
          _isLoading = false;
        });
        _startAutoScroll(_promos.length);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _promos = _defaultPromos;
          _isLoading = false;
        });
        _startAutoScroll(1);
      }
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {
      return AppColors.primary;
    }
  }

  List<Color> _gradientForColor(Color base) {
    // Shift hue slightly for a richer gradient
    final hsl = HSLColor.fromColor(base);
    final lighter = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
    final darker = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .toColor();
    return [darker, lighter];
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'contact': return Icons.phone_in_talk_rounded;
      case 'upgrade': return Icons.workspace_premium_rounded;
      default:        return Icons.local_offer_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (_isLoading)
          _buildShimmer()
        else ...[
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _promos.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => _PromoCardWidget(
                card: _promos[i],
                index: i,
              ),
            ),
          ),
          if (_promos.length > 1) ...[
            const SizedBox(height: 12),
            _PageDots(count: _promos.length, current: _currentPage),
          ],
        ],
      ],
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final grad = LinearGradient(
          colors: const [Color(0xFFE0E0E0), Color(0xFFF0F0F0), Color(0xFFE0E0E0)],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.5 + _shimmerCtrl.value * 3, 0),
          end: Alignment(-0.5 + _shimmerCtrl.value * 3, 0),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 148,
            decoration: BoxDecoration(
              gradient: grad,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ════════════════════════════════════════════════════════════════════════════

class _PromoCard {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final List<Color> bgColors;
  final IconData iconData;
  final String? imageUrl;
  final Color? accentColor;

  const _PromoCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.bgColors,
    required this.iconData,
    this.imageUrl,
    this.accentColor,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// PROMO CARD WIDGET  — entrance animation + press effect
// ════════════════════════════════════════════════════════════════════════════

class _PromoCardWidget extends StatefulWidget {
  final _PromoCard card;
  final int index;

  const _PromoCardWidget({required this.card, required this.index});

  @override
  State<_PromoCardWidget> createState() => _PromoCardWidgetState();
}

class _PromoCardWidgetState extends State<_PromoCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)));
    _scale = Tween(begin: 0.94, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final luminance = card.bgColors.first.computeLuminance();
    final isDark = luminance < 0.45;
    final textColor  = isDark ? Colors.white : Colors.black87;
    final subColor   = isDark ? Colors.white.withOpacity(0.78) : Colors.black54;
    final btnBg      = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);
    final btnBorder  = isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.15);

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: card.bgColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: card.bgColors.first.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Decorative background circles
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: -40,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left: image or icon
                            _buildMedia(card, isDark),
                            const SizedBox(width: 16),
                            // Middle: text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Tag pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'PROMO',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    card.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (card.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      card.subtitle,
                                      style: TextStyle(
                                        color: subColor,
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Right: button
                            if (card.buttonLabel.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: btnBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: btnBorder),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      card.buttonLabel,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: textColor,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(_PromoCard card, bool isDark) {
    if (card.imageUrl != null && card.imageUrl!.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            card.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconBox(card, isDark),
          ),
        ),
      );
    }
    return _iconBox(card, isDark);
  }

  Widget _iconBox(_PromoCard card, bool isDark) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDark ? 0.18 : 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        card.iconData,
        color: isDark ? Colors.white : Colors.black87,
        size: 28,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PAGE DOTS INDICATOR
// ════════════════════════════════════════════════════════════════════════════

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}