// lib/core/widgets/top_action_icons.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/constants/admin_constants.dart';
import '../constants/app_colors.dart';

class TopActionIcons extends StatefulWidget {
  final bool isAdmin;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final Color iconColor;
  final Color badgeColor;

  const TopActionIcons({
    super.key,
    required this.isAdmin,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.iconColor = Colors.white,
    this.badgeColor = AppColors.error,
  });

  @override
  State<TopActionIcons> createState() => _TopActionIconsState();
}

class _TopActionIconsState extends State<TopActionIcons> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _unreadMessages = 0;
  RealtimeChannel? _conversationChannel;

  bool get _isAdminByEmail {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _loadUnreadMessages();
    _subscribeConversationChanges();
  }

  @override
  void didUpdateWidget(covariant TopActionIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdmin != widget.isAdmin) {
      _loadUnreadMessages();
      _subscribeConversationChanges();
    }
  }

  @override
  void dispose() {
    _conversationChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadMessages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      if (widget.isAdmin || _isAdminByEmail) {
        final result = await _supabase
            .from('conversations')
            .select('id')
            .eq('is_read_admin', false);

        if (mounted) {
          setState(() => _unreadMessages = (result as List).length);
        }
      } else {
        final result = await _supabase
            .from('conversations')
            .select('id')
            .eq('client_id', user.id)
            .eq('is_read_client', false);

        if (mounted) {
          setState(() => _unreadMessages = (result as List).length);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _unreadMessages = 0);
    }
  }

  void _subscribeConversationChanges() {
    _conversationChannel?.unsubscribe();

    _conversationChannel = _supabase
        .channel('top_action_conversations_${widget.isAdmin}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversations',
      callback: (_) => _loadUnreadMessages(),
    )
        .subscribe();
  }

  void _openMessages() {
    if (widget.isAdmin || _isAdminByEmail) {
      context.push('/admin/messages').then((_) => _loadUnreadMessages());
    } else {
      context.push('/chat').then((_) => _loadUnreadMessages());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BadgeIconButton(
          icon: Icons.notifications_none_rounded,
          count: widget.notificationCount,
          iconColor: widget.iconColor,
          badgeColor: widget.badgeColor,
          onTap: widget.onNotificationTap ??
                  () {
                if (widget.isAdmin || _isAdminByEmail) {
                  context.push('/admin/projects');
                } else {
                  context.push('/portal');
                }
              },
        ),
        const SizedBox(width: 8),
        _BadgeIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          count: _unreadMessages,
          iconColor: widget.iconColor,
          badgeColor: widget.badgeColor,
          onTap: _openMessages,
        ),
      ],
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color iconColor;
  final Color badgeColor;
  final VoidCallback onTap;

  const _BadgeIconButton({
    required this.icon,
    required this.count,
    required this.iconColor,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: iconColor == Colors.white
                      ? Colors.white.withOpacity(0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconColor == Colors.white
                        ? Colors.white.withOpacity(0.18)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
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
                    border: Border.all(color: Colors.white, width: 1.5),
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
    );
  }
}