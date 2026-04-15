// lib/features/hub/components/hub_tools_section.dart
//
// Business Tools grid showing Free tools + Pro-locked tools.
// Free tools are accessible immediately; Pro tools show a gold lock badge.

import 'package:flutter/material.dart';
import '../constants/hub_colors.dart';

class HubToolsSection extends StatelessWidget {
  const HubToolsSection({super.key});

  static const _freeTools = [
    _ToolData(icon: Icons.receipt_long_rounded,            label: 'Invoice Gen',    locked: false),
    _ToolData(icon: Icons.account_balance_wallet_rounded,  label: 'Expense Track',  locked: false),
    _ToolData(icon: Icons.description_rounded,             label: 'Proposals',      locked: false),
    _ToolData(icon: Icons.auto_awesome_rounded,            label: 'AI Captions',    locked: false),
  ];

  static const _proTools = [
    _ToolData(icon: Icons.people_alt_rounded,    label: 'Full CRM',     locked: true),
    _ToolData(icon: Icons.point_of_sale_rounded, label: 'POS Lite',     locked: true),
    _ToolData(icon: Icons.bar_chart_rounded,     label: 'Analytics',    locked: true),
    _ToolData(icon: Icons.smart_toy_rounded,     label: 'AI Reports',   locked: true),
    _ToolData(icon: Icons.cloud_sync_rounded,    label: 'Cloud Backup', locked: true),
    _ToolData(icon: Icons.group_add_rounded,     label: 'Multi-User',   locked: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Free tools ────────────────────────────────────────
          _ToolGroupLabel(
            label: 'FREE TOOLS',
            color: HubColors.success,
            icon: null,
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: _freeTools.map((t) => _ToolCell(data: t)).toList(),
          ),
          const SizedBox(height: 18),

          // ── Pro tools ─────────────────────────────────────────
          _ToolGroupLabel(
            label: 'PRO TOOLS',
            color: HubColors.gold,
            icon: Icons.workspace_premium_rounded,
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: _proTools.map((t) => _ToolCell(data: t)).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group label badge
// ─────────────────────────────────────────────────────────────────────────────
class _ToolGroupLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ToolGroupLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual tool cell
// ─────────────────────────────────────────────────────────────────────────────
class _ToolCell extends StatelessWidget {
  final _ToolData data;
  const _ToolCell({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: data.locked ? HubColors.background : HubColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: data.locked
              ? HubColors.border
              : HubColors.primary.withOpacity(0.2),
        ),
        boxShadow: data.locked
            ? null
            : [
                BoxShadow(
                  color: HubColors.primary.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with optional lock overlay
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.locked
                      ? HubColors.border
                      : HubColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  data.icon,
                  color: data.locked ? HubColors.textHint : HubColors.primary,
                  size: 20,
                ),
              ),
              if (data.locked)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: HubColors.goldGrad,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: data.locked ? HubColors.textHint : HubColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
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
class _ToolData {
  final IconData icon;
  final String label;
  final bool locked;

  const _ToolData({
    required this.icon,
    required this.label,
    required this.locked,
  });
}