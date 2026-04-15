// lib/features/home/screens/components/home_hero_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/notification_store.dart';
import '../../../../core/cart/cart_store.dart';
import '../../../../admin/constants/admin_constants.dart';
import '../../../chat/screens/chat_screen.dart';
import '../../../chat/screens/admin_conversations_screen.dart';

class HomeHeroSection extends StatefulWidget {
  final String userName;
  final String greeting;
  final VoidCallback onProfileTap;

  const HomeHeroSection({
    super.key,
    required this.userName,
    required this.greeting,
    required this.onProfileTap,
  });

  @override
  State<HomeHeroSection> createState() => _HomeHeroSectionState();
}

class _HomeHeroSectionState extends State<HomeHeroSection> {
  final _store    = NotificationStore.instance;
  final _supabase = Supabase.instance.client;
  int _unreadMessages = 0;

  bool get _isAdmin {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
    CartStore.instance.addListener(_rebuild);
    _loadUnreadMessages();
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    CartStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _loadUnreadMessages() async {
    try {
      if (_isAdmin) {
        final data = await _supabase
            .from('conversations')
            .select('id')
            .eq('is_read_admin', false);
        if (mounted) {
          setState(() => _unreadMessages = (data as List).length);
        }
      } else {
        final uid = _supabase.auth.currentUser?.id;
        if (uid == null) return;
        final data = await _supabase
            .from('conversations')
            .select('id')
            .eq('client_id', uid)
            .eq('is_read_client', false);
        if (mounted) {
          setState(() => _unreadMessages = (data as List).length);
        }
      }
    } catch (_) {}
  }

  void _openNotifications() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => const _NotificationPanel(),
    );
  }

  void _openChat() {
    HapticFeedback.lightImpact();
    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AdminConversationsScreen()),
      ).then((_) => _loadUnreadMessages());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ).then((_) => _loadUnreadMessages());
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread     = _store.unreadCount;
    final cartCount  = CartStore.instance.totalCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Greeting ──────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.greeting,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.userName.split(' ').first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // ── Action buttons ─────────────────────────────────
              Row(
                children: [
                  // Cart button (hidden for admin)
                  if (!_isAdmin) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/cart');
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1),
                            ),
                            child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white, size: 20),
                          ),
                          if (cartCount > 0)
                            Positioned(
                              top: -4, right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B5C),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.primary,
                                      width: 1.5),
                                ),
                                child: Text(
                                  cartCount > 9 ? '9+' : '$cartCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Chat button
                  GestureDetector(
                    onTap: _openChat,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1),
                          ),
                          child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white, size: 20),
                        ),
                        if (_unreadMessages > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              child: Text(
                                _unreadMessages > 9
                                    ? '9+'
                                    : '$_unreadMessages',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Bell button
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1),
                          ),
                          child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white, size: 22),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              child: Text(
                                unread > 9 ? '9+' : '$unread',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Avatar
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Explore banner ────────────────────────────────────
          GestureDetector(
            onTap: () => context.go('/marketplace'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset('assets/icons/tokilologo.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tokilo Business Hub',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(
                            'IT Services · Software · Infrastructure',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Explore',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel();

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  final _store    = NotificationStore.instance;
  final _supabase = Supabase.instance.client;

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    _store.addListener(_rebuild);
  }

  @override
  void dispose() {
    _store.removeListener(_rebuild);
    super.dispose();
  }

  bool get _isAdmin {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  void _navigate(BuildContext context, AppNotification n) {
    switch (n.type) {
      case NotifType.project:
        if (n.refTable == 'client_projects') {
          if (_isAdmin) {
            context.go('/admin/projects');
          } else {
            context.go('/portal');
          }
        } else if (n.refTable == 'conversations') {
          if (_isAdmin) {
            Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const AdminConversationsScreen()));
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatScreen()));
          }
        }
        break;
      case NotifType.product:
        context.go('/marketplace');
        break;
      case NotifType.portfolio:
        context.go('/marketplace');
        break;
      case NotifType.promo:
        context.go('/marketplace');
        break;
      case NotifType.alert:
      case NotifType.system:
        if (n.refTable == 'conversations') {
          if (_isAdmin) {
            Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const AdminConversationsScreen()));
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatScreen()));
          }
        } else {
          context.go('/home');
        }
        break;
    }
  }

  IconData _icon(NotifType t) {
    switch (t) {
      case NotifType.project:   return Icons.folder_special_rounded;
      case NotifType.product:   return Icons.devices_rounded;
      case NotifType.portfolio: return Icons.work_rounded;
      case NotifType.promo:     return Icons.local_offer_rounded;
      case NotifType.alert:     return Icons.warning_amber_rounded;
      case NotifType.system:    return Icons.chat_bubble_rounded;
    }
  }

  Color _color(NotifType t) {
    switch (t) {
      case NotifType.project:   return const Color(0xFF3B82F6);
      case NotifType.product:   return const Color(0xFF8B5CF6);
      case NotifType.portfolio: return const Color(0xFF10B981);
      case NotifType.promo:     return const Color(0xFFF59E0B);
      case NotifType.alert:     return const Color(0xFFEF4444);
      case NotifType.system:    return AppColors.primary;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final items  = _store.all;
    final unread = _store.unreadCount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5)),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('$unread new',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                if (unread > 0)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _store.markAllRead();
                    },
                    child: const Text('Mark all read',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE8EDF2)),

          Expanded(
            child: _store.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : items.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _store.refresh,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 72,
                              color: Color(0xFFEFF3F8)),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction:
                                  DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 20),
                                color: const Color(0xFFEF4444)
                                    .withOpacity(0.08),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 22),
                              ),
                              onDismissed: (_) {
                                HapticFeedback.mediumImpact();
                                _store.remove(n.id);
                              },
                              child: _NotifTile(
                                notif:     n,
                                icon:      _icon(n.type),
                                color:     _color(n.type),
                                timeLabel: _timeAgo(n.createdAt),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _store.markRead(n.id);
                                  Navigator.pop(context);
                                  _navigate(context, n);
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),

          if (items.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _store.clearAll();
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text('Clear All Notifications',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B))),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: const Color(0xFFEFF9FB),
                borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.notifications_none_rounded,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text("You're all caught up!",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('No notifications right now.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF94A3B8))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final IconData        icon;
  final Color           color;
  final String          timeLabel;
  final VoidCallback    onTap;

  const _NotifTile({
    required this.notif,
    required this.icon,
    required this.color,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: notif.isRead
            ? Colors.transparent
            : color.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: notif.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(timeLabel,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: notif.isRead
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 11,
                          color: color.withOpacity(0.6)),
                      const SizedBox(width: 3),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                            fontSize: 10,
                            color: color.withOpacity(0.6),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 4)
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}