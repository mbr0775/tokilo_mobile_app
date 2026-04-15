// lib/features/hub/components/hub_pricing_section.dart
//
// Two pricing cards: Free plan (QAR 0) and Pro plan (QAR 149/month).
// Pro card uses the hero gradient with a red "Best Value" badge.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubPricingSection extends StatelessWidget {
  const HubPricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Free plan
          _PricingCard(
            planName: 'Free',
            price: 'QAR 0',
            period: '/ forever',
            cardGradient: null,
            bgColor: HubColors.surface,
            textColor: HubColors.textPrimary,
            isFeatured: false,
            features: const [
              'Invoice generator (5/month)',
              'Basic expense tracking',
              'Proposal generator (3/month)',
              'AI caption creator',
              'Service marketplace access',
              'Client portal (view only)',
            ],
            ctaLabel: 'Get Started Free',
            ctaGradient: HubColors.primaryGrad,
            onCtaTap: () {},
          ),
          const SizedBox(height: 16),

          // Pro plan
          _PricingCard(
            planName: 'Pro',
            price: 'QAR 149',
            period: '/ month',
            cardGradient: HubColors.heroGrad,
            bgColor: null,
            textColor: Colors.white,
            isFeatured: true,
            features: const [
              'Everything in Free',
              'Full CRM system',
              'POS Lite + inventory',
              'Multi-user access (up to 5)',
              'Cloud backup & sync',
              'Sales analytics dashboard',
              'AI-powered business reports',
              'Priority 24/7 support',
            ],
            ctaLabel: 'Upgrade to Pro',
            ctaGradient: HubColors.redGrad,
            onCtaTap: () {},
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable pricing card
// ─────────────────────────────────────────────────────────────────────────────
class _PricingCard extends StatelessWidget {
  final String planName;
  final String price;
  final String period;
  final LinearGradient? cardGradient;
  final Color? bgColor;
  final Color textColor;
  final bool isFeatured;
  final List<String> features;
  final String ctaLabel;
  final LinearGradient ctaGradient;
  final VoidCallback onCtaTap;

  const _PricingCard({
    required this.planName,
    required this.price,
    required this.period,
    required this.cardGradient,
    required this.bgColor,
    required this.textColor,
    required this.isFeatured,
    required this.features,
    required this.ctaLabel,
    required this.ctaGradient,
    required this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: cardGradient,
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: cardGradient == null
            ? Border.all(color: HubColors.border)
            : null,
        boxShadow: [
          BoxShadow(
            color: HubColors.primary.withOpacity(isFeatured ? 0.25 : 0.06),
            blurRadius: isFeatured ? 24 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Plan name + badge row ───────────────────────────
          Row(
            children: [
              Text(
                planName,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              if (isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: HubColors.redGrad,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚡ Best Value',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Price row ───────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  period,
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: textColor.withOpacity(0.12), height: 1),
          const SizedBox(height: 16),

          // ── Feature list ────────────────────────────────────
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: (isFeatured ? HubColors.success : HubColors.primary)
                          .withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: isFeatured
                          ? HubColors.success
                          : HubColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── CTA button ──────────────────────────────────────
          GestureDetector(
            onTap: onCtaTap,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: ctaGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: ctaGradient.colors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  ctaLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}