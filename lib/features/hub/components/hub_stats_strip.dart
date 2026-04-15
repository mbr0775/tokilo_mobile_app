// lib/features/hub/components/hub_stats_strip.dart
//
// Updated: services → portfolio table for project count
// Stats: Projects · Products · Clients · 24/7 Support

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/hub_colors.dart';

class HubStatsStrip extends StatefulWidget {
  const HubStatsStrip({super.key});

  @override
  State<HubStatsStrip> createState() => _HubStatsStripState();
}

class _HubStatsStripState extends State<HubStatsStrip> {
  final _supabase = Supabase.instance.client;

  bool _loading        = true;
  int  _projectsCount  = 0;  // portfolio + client_projects combined
  int  _productsCount  = 0;
  int  _clientsCount   = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Portfolio (manually added projects)
      final portfolio = await _supabase
          .from('portfolio')
          .select('id')
          .eq('is_active', true)
          .count();

      // Client submitted projects
      final clientProjects = await _supabase
          .from('client_projects')
          .select('id')
          .count();

      // IT Products
      final products = await _supabase
          .from('it_products')
          .select('id')
          .eq('is_active', true)
          .count();

      // Registered users (profiles)
      int clients = 0;
      try {
        final profilesRes = await _supabase
            .from('profiles')
            .select('id')
            .count();
        clients = profilesRes.count ?? 0;
      } catch (_) {
        clients = 0;
      }

      if (mounted) {
        setState(() {
          _projectsCount = (portfolio.count ?? 0) + (clientProjects.count ?? 0);
          _productsCount = products.count ?? 0;
          _clientsCount  = clients;
          _loading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        value: _loading ? '—' : '${_projectsCount}+',
        label: 'Projects',
      ),
      _StatItem(
        value: _loading ? '—' : '${_productsCount}+',
        label: 'Products',
      ),
      _StatItem(
        value: _loading ? '—' : _fmt(_clientsCount),
        label: 'Clients',
      ),
      const _StatItem(
        value: '24/7',
        label: 'Support',
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HubColors.border),
        boxShadow: [
          BoxShadow(
            color: HubColors.primary.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _loading
          ? const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: HubColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          : Row(
              children: stats.asMap().entries.map((e) {
                final isLast = e.key == stats.length - 1;
                return Expanded(
                  child: _StatCell(
                    item: e.value,
                    showDivider: !isLast,
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final _StatItem item;
  final bool showDivider;

  const _StatCell({required this.item, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                right: BorderSide(color: HubColors.border, width: 1),
              ),
            )
          : null,
      child: Column(
        children: [
          Text(
            item.value,
            style: const TextStyle(
              color: HubColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: const TextStyle(
              color: HubColors.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String value, label;
  const _StatItem({required this.value, required this.label});
}