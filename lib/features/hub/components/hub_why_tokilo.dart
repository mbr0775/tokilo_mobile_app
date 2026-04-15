// lib/features/hub/components/hub_why_tokilo.dart
//
// 3x2 grid showcasing six trust/credibility pillars:
// ISO Certified, Fast Deployment, 24/7 Support, Secure, Cloud, Fair Pricing.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubWhyTokilo extends StatelessWidget {
  const HubWhyTokilo({super.key});

  static const _reasons = [
    _WhyData(
      icon: Icons.verified_rounded,
      label: 'ISO Certified',
      sub: 'Standards-compliant',
    ),
    _WhyData(
      icon: Icons.bolt_rounded,
      label: 'Fast Deployment',
      sub: 'Quick turnaround',
    ),
    _WhyData(
      icon: Icons.support_agent_rounded,
      label: '24/7 Support',
      sub: 'Always available',
    ),
    _WhyData(
      icon: Icons.lock_rounded,
      label: 'Secure & Private',
      sub: 'Enterprise-grade',
    ),
    _WhyData(
      icon: Icons.cloud_done_rounded,
      label: 'Cloud Hosted',
      sub: 'AWS & Azure',
    ),
    _WhyData(
      icon: Icons.price_check_rounded,
      label: 'Fair Pricing',
      sub: 'Transparent costs',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading (inline — not using HubSectionHeader to avoid
        // duplicate import; kept self-contained)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why Choose Tokilo?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: HubColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Trusted by businesses across Qatar',
                style: TextStyle(
                  fontSize: 12.5,
                  color: HubColors.textSec,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.78,
            children: _reasons.map((r) => _WhyCell(data: r)).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual cell
// ─────────────────────────────────────────────────────────────────────────────
class _WhyCell extends StatelessWidget {
  final _WhyData data;
  const _WhyCell({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubColors.border),
        boxShadow: [
          BoxShadow(
            color: HubColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: HubColors.primaryGrad,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              color: HubColors.textPrimary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.sub,
            style: const TextStyle(
              fontSize: 9.5,
              color: HubColors.textSec,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _WhyData {
  final IconData icon;
  final String label, sub;
  const _WhyData({required this.icon, required this.label, required this.sub});
}