import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Business Tools'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Free tools
          _buildPlanBadge('Free Tools', AppColors.success),
          const SizedBox(height: 14),
          _buildToolsGrid(_freeTools),
          const SizedBox(height: 28),

          // Pro banner
          _buildProLockBanner(),
          const SizedBox(height: 16),

          // Pro tools (locked)
          _buildPlanBadge('Pro Tools', AppColors.primary),
          const SizedBox(height: 14),
          _buildToolsGrid(_proTools, locked: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const _freeTools = [
    {'label': 'Invoice\nGenerator', 'icon': Icons.receipt_outlined, 'color': Color(0xFF10B981)},
    {'label': 'Expense\nTracker', 'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF3B82F6)},
    {'label': 'Proposal\nBuilder', 'icon': Icons.description_outlined, 'color': Color(0xFFF59E0B)},
    {'label': 'AI Caption\nCreator', 'icon': Icons.auto_awesome_outlined, 'color': Color(0xFFEC4899)},
  ];

  static const _proTools = [
    {'label': 'Full CRM\nSystem', 'icon': Icons.people_alt_outlined, 'color': Color(0xFF1A73E8)},
    {'label': 'POS Lite &\nInventory', 'icon': Icons.point_of_sale_outlined, 'color': Color(0xFF8B5CF6)},
    {'label': 'Sales\nAnalytics', 'icon': Icons.bar_chart_rounded, 'color': Color(0xFFEF4444)},
    {'label': 'AI Business\nReports', 'icon': Icons.smart_toy_outlined, 'color': Color(0xFF00C9B1)},
    {'label': 'Cloud\nBackup', 'icon': Icons.cloud_upload_outlined, 'color': Color(0xFF64748B)},
    {'label': 'Multi-user\nAccess', 'icon': Icons.group_outlined, 'color': Color(0xFFF97316)},
  ];

  Widget _buildPlanBadge(String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsGrid(List<Map<String, dynamic>> tools, {bool locked = false}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final tool = tools[i];
        final color = tool['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tool['icon'] as IconData, color: color, size: 20),
                  ),
                  Text(
                    tool['label'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              if (locked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.lock_rounded, color: AppColors.textHint, size: 18),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProLockBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock Pro Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('Subscribe to Pro Plan starting at QAR 99/month', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Go Pro', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}