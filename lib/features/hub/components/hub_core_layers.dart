// lib/features/hub/components/hub_core_layers.dart
//
// 2x2 grid showing the four core layers of the Tokilo Business Hub:
// Client Portal, Business Tools, Service Marketplace, Pro Subscription.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubCoreLayersGrid extends StatelessWidget {
  const HubCoreLayersGrid({super.key});

  static const _layers = [
    _LayerData(
      icon: Icons.dashboard_customize_rounded,
      title: 'Client Portal',
      desc: 'Track projects, raise tickets, chat with team & download invoices.',
      gradient: LinearGradient(
        colors: [Color(0xFF483D8B), Color(0xFF6B5FBD)],
      ),
      tag: 'Retention',
    ),
    _LayerData(
      icon: Icons.construction_rounded,
      title: 'Business Tools',
      desc: 'Invoice, expense tracker, CRM, POS Lite, AI reports & more.',
      gradient: LinearGradient(
        colors: [Color(0xFFF82727), Color(0xFFFF6B6B)],
      ),
      tag: 'Productivity',
    ),
    _LayerData(
      icon: Icons.storefront_rounded,
      title: 'Service Marketplace',
      desc: 'Book IT, digital, CCTV, cybersecurity & network services.',
      gradient: LinearGradient(
        colors: [Color(0xFF7C6FCD), Color(0xFFAB9FE8)],
      ),
      tag: 'Revenue',
    ),
    _LayerData(
      icon: Icons.workspace_premium_rounded,
      title: 'Pro Subscription',
      desc: 'Freemium SaaS — unlock advanced tools & analytics.',
      gradient: LinearGradient(
        colors: [Color(0xFFFFB940), Color(0xFFFF8C42)],
      ),
      tag: 'SaaS',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: _layers.map((l) => _CoreLayerCard(data: l)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual card with press animation
// ─────────────────────────────────────────────────────────────────────────────
class _CoreLayerCard extends StatefulWidget {
  final _LayerData data;
  const _CoreLayerCard({required this.data});

  @override
  State<_CoreLayerCard> createState() => _CoreLayerCardState();
}

class _CoreLayerCardState extends State<_CoreLayerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () {},
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HubColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HubColors.border),
            boxShadow: [
              BoxShadow(
                color: HubColors.primary.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient icon container
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: d.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: d.gradient.colors.first.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(d.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                d.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: HubColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  d.desc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: HubColors.textSec,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              // Gradient tag pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: d.gradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d.tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _LayerData {
  final IconData icon;
  final String title, desc, tag;
  final LinearGradient gradient;

  const _LayerData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gradient,
    required this.tag,
  });
}