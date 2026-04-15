
// lib/features/hub/components/hub_section_header.dart
//
// Reusable section title + subtitle used across all hub sections.
// Has a decorative left accent bar aligned to the right.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubSectionHeader extends StatelessWidget {
  final String title;
  final String sub;

  const HubSectionHeader({
    super.key,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: HubColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: HubColors.textSec,
                  ),
                ),
              ],
            ),
          ),
          // Decorative right accent bar
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              gradient: HubColors.primaryGrad,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}