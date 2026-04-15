// lib/features/home/screens/components/home_services_section.dart
//
// Shows the 7 permanent Tokilo business divisions as horizontal cards.
// Tapping "View All" → /marketplace
// Tapping a card → /marketplace with that division pre-selected.
// Data is 100% hardcoded from tokilo_services_data.dart — no Supabase call.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/tokilo_services_data.dart';

class HomeServicesSection extends StatelessWidget {
  const HomeServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Our Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () => context.go('/marketplace'),
                child: const Text('View All',
                    style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Horizontal division cards ──────────────────────
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: kTokiloDivisions.length,
            itemBuilder: (context, index) {
              final div = kTokiloDivisions[index];
              return _DivisionCard(division: div, index: index);
            },
          ),
        ),
      ],
    );
  }
}

class _DivisionCard extends StatelessWidget {
  final TDivision division;
  final int index;

  const _DivisionCard({required this.division, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/marketplace', extra: {'divisionIndex': index}),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coloured icon header
              Container(
                height: 72,
                width: double.infinity,
                color: division.bgColor,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: division.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(division.icon, color: division.color, size: 24),
                      ),
                    ),
                    // Service count badge
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: division.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${division.services.length}',
                          style: TextStyle(color: division.color, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        division.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Emoji + arrow row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(division.emoji, style: const TextStyle(fontSize: 14)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: division.color),
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
    );
  }
}