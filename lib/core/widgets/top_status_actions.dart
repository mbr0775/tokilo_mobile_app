// lib/core/widgets/top_status_actions.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/constants/admin_constants.dart';
import '../constants/app_colors.dart';

class TopStatusActions extends StatefulWidget {
  final bool isAdmin;
  final Color iconColor;
  final bool compact;

  const TopStatusActions({
    super.key,
    required this.isAdmin,
    this.iconColor = Colors.white,
    this.compact = false,
  });

  @override
  State<TopStatusActions> createState() => _TopStatusActionsState();
}

class _TopStatusActionsState extends State<TopStatusActions> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _unreadNotifications = 0;
  int _unreadMessages = 0;

  bool _isLoadingCounts = false;

  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _conversationChannel;
  Timer? _debounceTimer;

  bool get _isAdminByEmail {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  bool get _isAdminEffective => widget.isAdmin || _isAdminByEmail;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _subscribeRealtime();
  }

  @override
  void didUpdateWidget(covariant TopStatusActions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isAdmin != widget.isAdmin) {
      _loadCounts();
      _subscribeRealtime();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _notificationChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();
    super.dispose();
  }

  void _scheduleCountReload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadCounts();
      }
    });
  }

  Future<void> _loadCounts() async {
    if (_isLoadingCounts) return;

    setState(() => _isLoadingCounts = true);

    try {
      await Future.wait([
        _loadNotificationCount(),
        _loadMessageCount(),
      ]).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Do not crash the screen if one badge count fails.
    } finally {
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _unreadNotifications = 0);
        return;
      }

      if (_isAdminEffective) {
        final data = await _supabase
            .from('client_projects')
            .select('id')
            .eq('status', 'pending')
            .timeout(const Duration(seconds: 8));

        if (mounted) {
          setState(() => _unreadNotifications = (data as List).length);
        }
      } else {
        final results = await Future.wait([
          _supabase
              .from('project_notifications')
              .select('id')
              .eq('recipient_id', user.id)
              .eq('is_read', false),
          _supabase.rpc('tokilo_notification_feed', params: {'p_limit': 1}),
        ]).timeout(const Duration(seconds: 8));
        final feed = results[1] as List;
        final accountUnread = feed.isEmpty
            ? 0
            : (feed.first['unread_total'] as num).toInt();
        if (mounted)
          setState(
            () => _unreadNotifications =
                (results[0] as List).length + accountUnread,
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unreadNotifications = 0);
      }
    }
  }

  Future<void> _loadMessageCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _unreadMessages = 0);
        return;
      }

      if (_isAdminEffective) {
        final data = await _supabase
            .from('conversations')
            .select('id')
            .eq('is_read_admin', false)
            .timeout(const Duration(seconds: 8));

        if (mounted) {
          setState(() => _unreadMessages = (data as List).length);
        }
      } else {
        final data = await _supabase
            .from('conversations')
            .select('id')
            .eq('client_id', user.id)
            .eq('is_read_client', false)
            .timeout(const Duration(seconds: 8));

        if (mounted) {
          setState(() => _unreadMessages = (data as List).length);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unreadMessages = 0);
      }
    }
  }

  void _subscribeRealtime() {
    _notificationChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();

    final mode = _isAdminEffective ? 'admin' : 'client';

    _notificationChannel = _supabase
        .channel('top_status_notifications_$mode')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _isAdminEffective
              ? 'client_projects'
              : 'project_notifications',
          callback: (_) => _scheduleCountReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _scheduleCountReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_reads',
          callback: (_) => _scheduleCountReload(),
        )
        .subscribe();

    _conversationChannel = _supabase
        .channel('top_status_messages_$mode')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _scheduleCountReload(),
        )
        .subscribe();
  }

  Future<void> _openNotifications() async {
    if (_isAdminEffective) {
      await context.push('/admin/projects');
    } else {
      await context.push('/notifications');
    }

    if (mounted) {
      await _loadNotificationCount();
    }
  }

  Future<void> _openMessages() async {
    if (_isAdminEffective) {
      await context.push('/admin/messages');
    } else {
      await context.push('/chat');
    }

    if (mounted) {
      await _loadMessageCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopBadgeButton(
          icon: Icons.notifications_none_rounded,
          count: _unreadNotifications,
          iconColor: widget.iconColor,
          badgeColor: AppColors.warning,
          onTap: _openNotifications,
          compact: widget.compact,
        ),
        const SizedBox(width: 8),
        _TopBadgeButton(
          icon: Icons.chat_bubble_outline_rounded,
          count: _unreadMessages,
          iconColor: widget.iconColor,
          badgeColor: AppColors.error,
          onTap: _openMessages,
          compact: widget.compact,
        ),
      ],
    );
  }
}

class _TopBadgeButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color iconColor;
  final Color badgeColor;
  final VoidCallback onTap;
  final bool compact;

  const _TopBadgeButton({
    required this.icon,
    required this.count,
    required this.iconColor,
    required this.badgeColor,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final bool isWhiteIcon = iconColor == Colors.white;

    return Semantics(
      button: true,
      label: icon == Icons.notifications_none_rounded
          ? 'Notifications, $count unread'
          : 'Messages, $count unread',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: compact
                        ? Colors.transparent
                        : isWhiteIcon
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(compact ? 24 : 14),
                    border: compact
                        ? null
                        : Border.all(
                            color: compact
                                ? Colors.transparent
                                : isWhiteIcon
                                ? Colors.white.withValues(alpha: 0.18)
                                : AppColors.border,
                          ),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      border: compact
                          ? null
                          : Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
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
