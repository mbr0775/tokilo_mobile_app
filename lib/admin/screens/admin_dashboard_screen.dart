// lib/admin/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/top_status_actions.dart';
import '../../core/widgets/tokilo_motion.dart';
import 'admin_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _portfolioCount = 0;
  int _clientReqCount = 0;
  int _pendingCount = 0;
  int _showcaseCount = 0;
  int _bannersCount = 0;
  int _promosCount = 0;
  int _unreadMessages = 0;
  bool _isLoading = true;
  bool _statsError = false;

  RealtimeChannel? _dashboardChannel;
  RealtimeChannel? _conversationChannel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _dashboardChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _statsError = false;
    });

    try {
      final portfolio = await _supabase.from('portfolio').select('id').count();

      final clientReq = await _supabase
          .from('client_projects')
          .select('id')
          .count();

      final pending = await _supabase
          .from('client_projects')
          .select('id')
          .eq('status', 'pending')
          .count();

      final unreadMessages = await _supabase
          .from('conversations')
          .select('id')
          .eq('is_read_admin', false);

      int banners = 0;
      int promos = 0;
      int showcase = 0;

      try {
        final b = await _supabase.from('home_banners').select('id').count();
        final p = await _supabase.from('home_promos').select('id').count();
        final s = await _supabase.from('project_showcase').select('id').count();

        banners = b.count;
        promos = p.count;
        showcase = s.count;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _portfolioCount = portfolio.count;
          _clientReqCount = clientReq.count;
          _pendingCount = pending.count;
          _showcaseCount = showcase;
          _bannersCount = banners;
          _promosCount = promos;
          _unreadMessages = (unreadMessages as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statsError = true;
        });
      }
    }
  }

  void _subscribeRealtime() {
    _dashboardChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();

    _dashboardChannel = _supabase
        .channel('admin_dashboard_projects')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_projects',
          callback: (_) => _loadStats(),
        )
        .subscribe();

    _conversationChannel = _supabase
        .channel('admin_dashboard_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _loadStats(),
        )
        .subscribe();
  }

  String get _adminName {
    final meta = _supabase.auth.currentUser?.userMetadata;
    return meta?['full_name']?.toString() ?? 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/dashboard',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AdminAppBar(
          title: 'Dashboard',
          currentPath: '/admin/dashboard',
          actions: [
            TopStatusActions(isAdmin: true, iconColor: AppColors.textPrimary),
            SizedBox(width: 10),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _statsError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your dashboard could not load. Please try again.',
                      ),
                      TextButton(
                        onPressed: _loadStats,
                        child: const Text('Retry dashboard'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadStats,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    ScrollReveal(child: _WelcomeBanner(adminName: _adminName)),
                    const SizedBox(height: 22),

                    if (_pendingCount > 0) ...[
                      _PendingAlert(
                        count: _pendingCount,
                        onTap: () => context.go('/admin/projects'),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_unreadMessages > 0) ...[
                      _MessageAlert(
                        count: _unreadMessages,
                        onTap: () => context.push('/admin/messages'),
                      ),
                      const SizedBox(height: 18),
                    ],

                    const _SectionTitle('Overview'),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          label: 'Total Projects',
                          value: '${_portfolioCount + _clientReqCount}',
                          icon: Icons.folder_special_rounded,
                          color: AppColors.primary,
                          onTap: () => context.go('/admin/portfolio'),
                        ),
                        _StatCard(
                          label: 'Pending Requests',
                          value: '$_pendingCount',
                          icon: Icons.pending_actions_rounded,
                          color: AppColors.warning,
                          onTap: () => context.go('/admin/projects'),
                        ),
                        _StatCard(
                          label: 'Unread Messages',
                          value: '$_unreadMessages',
                          icon: Icons.chat_bubble_rounded,
                          color: AppColors.error,
                          onTap: () => context.push('/admin/messages'),
                        ),
                        _StatCard(
                          label: 'Showcase Items',
                          value: '$_showcaseCount',
                          icon: Icons.photo_library_rounded,
                          color: AppColors.accent,
                          onTap: () => context.go('/admin/showcase'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    const _SectionTitle('Manage'),
                    const SizedBox(height: 12),

                    _ManageCard(
                      title: 'Client Project Requests',
                      subtitle: 'Review requests, progress, invoice and notes',
                      count:
                          '$_clientReqCount requests • $_pendingCount pending',
                      icon: Icons.assignment_rounded,
                      color: AppColors.success,
                      onTap: () => context.go('/admin/projects'),
                    ),
                    _ManageCard(
                      title: 'Messages',
                      subtitle: 'Reply to client conversations',
                      count: '$_unreadMessages unread',
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.error,
                      onTap: () => context.push('/admin/messages'),
                    ),
                    _ManageCard(
                      title: 'My Projects',
                      subtitle: 'Add completed, ongoing and upcoming projects',
                      count: '$_portfolioCount projects',
                      icon: Icons.work_rounded,
                      color: AppColors.primary,
                      onTap: () => context.go('/admin/portfolio'),
                    ),
                    _ManageCard(
                      title: 'Project Showcase',
                      subtitle: 'Manage showcase images shown to users',
                      count: '$_showcaseCount items',
                      icon: Icons.photo_library_rounded,
                      color: AppColors.accent,
                      onTap: () => context.go('/admin/showcase'),
                    ),
                    _ManageCard(
                      title: 'Home Components',
                      subtitle: 'Manage banners, promos and home highlights',
                      count: '${_bannersCount + _promosCount} items',
                      icon: Icons.home_work_rounded,
                      color: AppColors.primary,
                      onTap: () => context.go('/admin/home-components'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String adminName;

  const _WelcomeBanner({required this.adminName});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F2F1),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TOKILO WORKSPACE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Good to see you,\n$adminName.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Projects, conversations and your next opportunity. All in one place.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _PendingAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AlertCard(
      icon: Icons.notifications_active_rounded,
      color: AppColors.warning,
      text: '$count project request${count == 1 ? '' : 's'} waiting for review',
      onTap: onTap,
    );
  }
}

class _MessageAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MessageAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AlertCard(
      icon: Icons.chat_bubble_rounded,
      color: AppColors.error,
      text: '$count unread client message${count == 1 ? '' : 's'}',
      onTap: onTap,
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  const _AlertCard({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 21),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ManageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManageCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    count,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
