// lib/features/hub/components/hub_hero_banner.dart
//
// Hero SliverAppBar + animated banner for TokiloHubScreen.
// Used as the FlexibleSpaceBar background inside a SliverAppBar.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/hub_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC: Sliver App Bar — drop this directly into a CustomScrollView sliver
// ─────────────────────────────────────────────────────────────────────────────
class HubSliverAppBar extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset>  slideAnim;
  final VoidCallback onUpgradeTap;

  const HubSliverAppBar({
    super.key,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      stretch: true,
      backgroundColor: HubColors.primaryDk,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: Colors.white, size: 20),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      actions: [
        HubProBadge(onTap: onUpgradeTap),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: const _HeroBannerContent(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE: Banner content (gradient, dots, float cards, text, CTAs)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBannerContent extends StatelessWidget {
  const _HeroBannerContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: HubColors.heroGrad),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20, left: -40,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Dot grid pattern
          Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
          // Main content row: text on left, float cards on right
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Left: text + CTAs ────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _BrandChip(),
                        const SizedBox(height: 14),
                        const Text(
                          'Business\nHub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'All-in-one business OS —\nclient portal, tools & IT.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            HubHeroCTA(
                              label: 'Explore',
                              icon: Icons.grid_view_rounded,
                              gradient: HubColors.redGrad,
                              onTap: () {},
                            ),
                            HubHeroCTA(
                              label: 'Get Pro',
                              icon: Icons.workspace_premium_rounded,
                              gradient: null,
                              outlined: true,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Right: float stat cards ──────────────────
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      HubFloatCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Revenue',
                        value: '+24%',
                        color: HubColors.success,
                      ),
                      const SizedBox(height: 10),
                      HubFloatCard(
                        icon: Icons.people_rounded,
                        label: 'Clients',
                        value: '1.2K+',
                        color: HubColors.gold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS (exported — reusable elsewhere in hub)
// ─────────────────────────────────────────────────────────────────────────────

/// Small brand chip shown at top of hero
class _BrandChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(Icons.business_rounded,
                color: HubColors.primary, size: 12),
          ),
          const SizedBox(width: 7),
          const Text(
            'Tokilo Technologies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold "Upgrade" badge shown in AppBar actions
class HubProBadge extends StatelessWidget {
  final VoidCallback onTap;
  const HubProBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: HubColors.goldGrad,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: HubColors.gold.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 13),
            SizedBox(width: 5),
            Text(
              'Upgrade',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating stat mini-card (shown on right side of hero)
class HubFloatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const HubFloatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero CTA button (solid gradient or outlined)
class HubHeroCTA extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final bool outlined;
  final VoidCallback onTap;

  const HubHeroCTA({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    this.outlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: outlined ? null : gradient,
          borderRadius: BorderRadius.circular(12),
          border: outlined
              ? Border.all(color: Colors.white.withOpacity(0.4))
              : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: gradient!.colors.first.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOT PATTERN PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    const radius = 1.5;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}