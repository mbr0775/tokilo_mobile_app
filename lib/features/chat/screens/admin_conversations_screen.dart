// lib/features/chat/screens/admin_conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_models.dart';
import 'chat_screen.dart';

class AdminConversationsScreen extends StatefulWidget {
  const AdminConversationsScreen({super.key});

  @override
  State<AdminConversationsScreen> createState() =>
      _AdminConversationsScreenState();
}

class _AdminConversationsScreenState
    extends State<AdminConversationsScreen> {
  final _supabase = Supabase.instance.client;
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('conversations')
          .select()
          .order('last_message_at', ascending: false);
      if (mounted) {
        setState(() {
          _conversations = (data as List)
              .map((e) => ConversationModel.fromMap(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('conversations_admin')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'conversations',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  int get _unreadCount =>
      _conversations.where((c) => !c.isReadAdmin).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF03404E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _conversations.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    itemBuilder: (_, i) =>
                        _convCard(_conversations[i]),
                  ),
                ),
    );
  }

  Widget _convCard(ConversationModel c) {
    final hasUnread = !c.isReadAdmin;
    final name      = c.clientName ?? c.clientEmail ?? 'Client';
    final initial   = name.substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: c.id,
            clientName:     c.clientName,
            clientEmail:    c.clientEmail,
          ),
        ),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withOpacity(0.35)
                : AppColors.border,
            width: hasUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Avatar with unread dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    initial,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _timeAgo(c.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastMessage ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (c.clientEmail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      c.clientEmail!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Conversations Yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Client messages will appear here',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
}