// lib/admin/screens/admin_dashboard_screen.dart
// UPDATED: Added Showcase quick action + manage card

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;

  int  _portfolioCount  = 0;
  int  _clientReqCount  = 0;
  int  _totalProjects   = 0;
  int  _productsCount   = 0;
  int  _bannersCount    = 0;
  int  _promosCount     = 0;
  int  _pendingCount    = 0;
  int  _showcaseCount   = 0;   // ← NEW
  bool _isLoading       = true;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final products  = await _supabase.from('it_products').select('id').count();
      final portfolio = await _supabase.from('portfolio').select('id').count();
      final clientReq = await _supabase.from('client_projects').select('id').count();
      final pending   = await _supabase.from('client_projects').select('id').eq('status', 'pending').count();

      int banners = 0, promos = 0, showcase = 0;
      try {
        final b = await _supabase.from('home_banners').select('id').count();
        final p = await _supabase.from('home_promos').select('id').count();
        final s = await _supabase.from('project_showcase').select('id').count(); // ← NEW
        banners  = b.count ?? 0;
        promos   = p.count ?? 0;
        showcase = s.count ?? 0;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _portfolioCount = portfolio.count ?? 0;
          _clientReqCount = clientReq.count ?? 0;
          _totalProjects  = _portfolioCount + _clientReqCount;
          _productsCount  = products.count ?? 0;
          _bannersCount   = banners;
          _promosCount    = promos;
          _pendingCount   = pending.count ?? 0;
          _showcaseCount  = showcase;
          _isLoading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _adminName {
    final meta = _supabase.auth.currentUser?.userMetadata;
    return meta?['full_name'] ?? 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/dashboard',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AdminAppBar(title: 'Dashboard', currentPath: '/admin/dashboard'),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadStats,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeBanner(),
                      const SizedBox(height: 24),

                      if (_pendingCount > 0) ...[
                        _buildPendingAlert(context),
                        const SizedBox(height: 16),
                      ],

                      _buildSectionTitle('Overview'),
                      const SizedBox(height: 14),
                      _buildStatsRows(context),
                      const SizedBox(height: 28),
                      _buildSectionTitle('Quick Actions'),
                      const SizedBox(height: 14),
                      _buildQuickActions(context),
                      const SizedBox(height: 28),
                      _buildSectionTitle('Manage Content'),
                      const SizedBox(height: 14),
                      _buildManageCards(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPendingAlert(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/admin/projects'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_pendingCount project request${_pendingCount == 1 ? '' : 's'} waiting for review',
                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFF59E0B), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                const SizedBox(height: 4),
                Text(_adminName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: const Text('⚡ Administrator',
                      style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.all(10),
            child: Image.asset('assets/icons/tokilologo.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRows(BuildContext context) {
    final row1 = [
      _StatData(label: 'Total Projects', value: '$_totalProjects', icon: Icons.folder_special_rounded,  color: AppColors.primary,         route: '/admin/portfolio'),
      _StatData(label: 'Pending',        value: '$_pendingCount',  icon: Icons.pending_actions_rounded, color: AppColors.warning,         route: '/admin/projects'),
    ];
    final row2 = [
      _StatData(label: 'My Projects',    value: '$_portfolioCount', icon: Icons.work_rounded,           color: AppColors.success,         route: '/admin/portfolio'),
      _StatData(label: 'Client Requests',value: '$_clientReqCount', icon: Icons.inbox_rounded,          color: const Color(0xFF8B5CF6),   route: '/admin/projects'),
    ];
    final row3 = [
      _StatData(label: 'IT Products',    value: '$_productsCount',  icon: Icons.devices_rounded,        color: const Color(0xFF8B5CF6),   route: '/admin/products'),
      _StatData(label: 'Showcase Items', value: '$_showcaseCount',  icon: Icons.photo_library_rounded,  color: AppColors.accent,          route: '/admin/showcase'),  // ← NEW
    ];

    return Column(
      children: [row1, row2, row3].map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: List.generate(row.length, (i) {
            final s = row[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => context.go(s.route),
                child: Container(
                  height: 90,
                  margin: EdgeInsets.only(left: i > 0 ? 7 : 0, right: i < row.length - 1 ? 7 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(s.icon, color: s.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text(s.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      )).toList(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'label': 'My\nProjects',  'icon': Icons.work_rounded,            'color': AppColors.primary,        'route': '/admin/portfolio'},
      {'label': 'Client\nReqs',  'icon': Icons.folder_special_rounded,  'color': AppColors.success,        'route': '/admin/projects'},
      {'label': 'Add\nProduct',  'icon': Icons.add_box_rounded,         'color': const Color(0xFF8B5CF6),  'route': '/admin/products'},
      {'label': 'Showcase',      'icon': Icons.photo_library_rounded,   'color': AppColors.accent,         'route': '/admin/showcase'},   // ← NEW
      {'label': 'View\nUsers',   'icon': Icons.people_alt_rounded,      'color': AppColors.warning,        'route': '/admin/users'},
      {'label': 'Messages',      'icon': Icons.chat_rounded,            'color': AppColors.accent,         'route': '/admin/messages'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        final color = a['color'] as Color;
        return GestureDetector(
          onTap: () => context.go(a['route'] as String),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Icon(a['icon'] as IconData, color: color, size: 22),
                  ),
                  if (a['route'] == '/admin/projects' && _pendingCount > 0)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: Center(
                          child: Text('$_pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(a['label'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManageCards(BuildContext context) {
    final cards = [
      {
        'title': 'Project Showcase',
        'desc':  'Add showcase images that appear in the home screen carousel',
        'icon':  Icons.photo_library_rounded,
        'color': AppColors.accent,
        'route': '/admin/showcase',
        'count': '$_showcaseCount items',
      },
      {
        'title': 'My Projects',
        'desc':  'Add and manage manually added offline projects with pricing',
        'icon':  Icons.work_rounded,
        'color': AppColors.primary,
        'route': '/admin/portfolio',
        'count': '$_portfolioCount projects',
      },
      {
        'title': 'Client Requests',
        'desc':  'Review requests, update status & progress, add invoices',
        'icon':  Icons.folder_special_rounded,
        'color': AppColors.success,
        'route': '/admin/projects',
        'count': '$_clientReqCount requests  •  $_pendingCount pending',
      },
      {
        'title': 'Manage IT Products',
        'desc':  'Control hardware & product catalog with pricing',
        'icon':  Icons.devices_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': '/admin/products',
        'count': '$_productsCount items',
      },
      {
        'title': 'Home Screen Components',
        'desc':  'Manage banners, promos & feature pills on home',
        'icon':  Icons.home_work_rounded,
        'color': AppColors.primary,
        'route': '/admin/home-components',
        'count': '${_bannersCount + _promosCount} items',
      },
    ];

    return Column(
      children: cards.map((card) {
        final color = card['color'] as Color;
        return GestureDetector(
          onTap: () => context.go(card['route'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(card['icon'] as IconData, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(card['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                        child: Text(card['count'] as String,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
}

class _StatData {
  final String label, value, route;
  final IconData icon;
  final Color color;
  const _StatData({required this.label, required this.value, required this.icon, required this.color, required this.route});
}