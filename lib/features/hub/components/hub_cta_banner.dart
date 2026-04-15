// lib/features/hub/components/hub_cta_banner.dart
//
// Bottom call-to-action banner with "Get Started Free" and "Contact Us"
// buttons on a deep DarkSlateBlue gradient background.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubCtaBanner extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onContactUs;

  const HubCtaBanner({
    super.key,
    required this.onGetStarted,
    required this.onContactUs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: HubColors.heroGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: HubColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30, left: -30,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ready to Transform\nYour Business?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join hundreds of businesses using\nTokilo Business Hub today.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Primary CTA
                  Expanded(
                    child: GestureDetector(
                      onTap: onGetStarted,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: HubColors.redGrad,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: HubColors.accentRed.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Get Started Free',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Secondary CTA
                  GestureDetector(
                    onTap: onContactUs,
                    child: Container(
                      height: 46,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          'Contact Us',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}