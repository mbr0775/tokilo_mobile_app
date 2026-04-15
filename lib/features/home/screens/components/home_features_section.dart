import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';

class HomeFeaturesSection extends StatefulWidget {
  const HomeFeaturesSection({super.key});

  @override
  State<HomeFeaturesSection> createState() => _HomeFeaturesSectionState();
}

class _HomeFeaturesSectionState extends State<HomeFeaturesSection> {
  final _supabase = Supabase.instance.client;
  List<_FeatureItem> _items = [];
  bool _isLoading = true;

  static const _defaults = [
    _FeatureItem(
      label: 'Certified Experts',
      icon: Icons.verified_rounded,
      color: Color(0xFF06768D),
      description: 'Top professionals, verified for quality.',
    ),
    _FeatureItem(
      label: 'Fast Delivery',
      icon: Icons.flash_on_rounded,
      color: Color(0xFF8B5CF6),
      description: 'Get your products delivered quickly.',
    ),
    _FeatureItem(
      label: '24/7 Support',
      icon: Icons.support_agent_rounded,
      color: Color(0xFF10B981),
      description: 'We are here for you anytime.',
    ),
    _FeatureItem(
      label: 'Best Pricing',
      icon: Icons.price_check_rounded,
      color: Color(0xFFF59E0B),
      description: 'Unbeatable prices, always.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = _defaults;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 175,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 175, // Fixed: increased from 140 to prevent overflow
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          final item = _items[i];
          return _GlassFeatureCard(
            item: item,
            delay: Duration(milliseconds: 100 * i),
          );
        },
      ),
    );
  }
}

class _FeatureItem {
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const _FeatureItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _GlassFeatureCard extends StatefulWidget {
  final _FeatureItem item;
  final Duration delay;

  const _GlassFeatureCard({required this.item, required this.delay});

  @override
  State<_GlassFeatureCard> createState() => _GlassFeatureCardState();
}

class _GlassFeatureCardState extends State<_GlassFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
    _scale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 180,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14, // Fixed: reduced from 18 to give column more room
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.item.color.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.item.color.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Fixed: don't force max height
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          widget.item.color.withOpacity(0.18),
                          widget.item.color.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(10), // Fixed: reduced from 12
                    child: Icon(
                      widget.item.icon,
                      color: widget.item.color,
                      size: 28, // Fixed: reduced from 32
                    ),
                  ),
                  const SizedBox(height: 10), // Fixed: reduced from 14
                  Text(
                    widget.item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Fixed: reduced from 15
                      color: AppColors.textPrimary.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 5), // Fixed: reduced from 6
                  Text(
                    widget.item.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,  // Fixed: reduced from 11.5
                      color: AppColors.textPrimary.withOpacity(0.7),
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
}