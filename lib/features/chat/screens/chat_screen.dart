// lib/features/chat/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../admin/constants/admin_constants.dart';
import '../models/chat_models.dart';

class ChatScreen extends StatefulWidget {
  final String?  conversationId;
  final String?  clientName;
  final String?  clientEmail;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.clientName,
    this.clientEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _supabase   = Supabase.instance.client;
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MessageModel> _messages     = [];
  String?            _conversationId;
  bool               _isLoading    = true;
  bool               _isSending    = false;
  String?            _errorMessage;

  bool               _isOnline     = false;
  DateTime?          _otherLastSeen;

  Timer?             _uiRefreshTimer;
  Timer?             _heartbeatTimer;
  Timer?             _offlineTimer;

  RealtimeChannel?   _channel;
  RealtimeChannel?   _presenceChannel;

  bool get _isAdmin {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  String get _senderName {
    final meta = _supabase.auth.currentUser?.userMetadata;
    return meta?['full_name'] ??
        _supabase.auth.currentUser?.email ??
        'User';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationId = widget.conversationId;
    _init();

    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _channel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _uiRefreshTimer?.cancel();
    _offlineTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _saveMyLastSeen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      // Re-fetch on resume to sync any read receipts missed while backgrounded
      _refreshMessages();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      _stopHeartbeat();
      _saveMyLastSeen();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Heartbeat
  // ─────────────────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _stopHeartbeat();
    _trackPresence();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _trackPresence();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _trackPresence() async {
    try {
      await _presenceChannel?.track({
        'user_id':   _supabase.auth.currentUser?.id,
        'is_admin':  _isAdmin,
        'online_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('>>> Track presence error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() {
      _messages      = [];
      _isLoading     = true;
      _errorMessage  = null;
      _isOnline      = false;
      _otherLastSeen = null;
    });

    if (_conversationId == null) {
      await _getOrCreateConversation();
    }

    if (_conversationId == null) {
      if (mounted) {
        setState(() {
          _isLoading    = false;
          _errorMessage = 'Could not load conversation. Please try again.';
        });
      }
      return;
    }

    await _loadMessages();
    await _loadOtherLastSeen();
    _subscribeRealtime();
    _subscribePresence();
    _subscribeLastSeenRealtime();
    await _markRead();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _getOrCreateConversation() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final existing = await _supabase
          .from('conversations')
          .select()
          .eq('client_id', uid)
          .maybeSingle();
      if (existing != null) {
        _conversationId = existing['id'];
      } else {
        final result = await _supabase
            .from('conversations')
            .insert({
              'client_id':    uid,
              'client_name':  _senderName,
              'client_email': _supabase.auth.currentUser?.email,
            })
            .select()
            .single();
        _conversationId = result['id'];
      }
    } catch (e) {
      debugPrint('>>> Conversation error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Messages
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    if (_conversationId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);

      if (mounted) {
        final list = (data as List)
            .map((e) => MessageModel.fromMap(e))
            .toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        setState(() {
          _messages  = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('>>> Load messages error: $e');
      if (mounted) {
        setState(() {
          _isLoading    = false;
          _errorMessage = 'Failed to load messages: $e';
        });
      }
    }
  }

  /// Silent refresh — re-fetches all messages without showing a loader.
  /// Used to sync is_read flags after mark-read or app resume.
  Future<void> _refreshMessages() async {
    if (_conversationId == null) return;
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);

      if (mounted) {
        final list = (data as List)
            .map((e) => MessageModel.fromMap(e))
            .toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        setState(() => _messages = list);
      }
    } catch (e) {
      debugPrint('>>> Refresh messages error: $e');
    }
  }

  void _subscribeRealtime() {
    if (_conversationId == null) return;
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('messages_$_conversationId')
        // ── New message inserted ──────────────────────────────────────────
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'messages',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value:  _conversationId!,
          ),
          callback: (payload) async {
            final msg = MessageModel.fromMap(payload.newRecord);
            if (mounted) {
              setState(() {
                final exists = _messages.any((m) => m.id == msg.id);
                if (!exists) {
                  _messages.add(msg);
                  _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                }
              });
              _scrollToBottom();
              // Mark the newly received message as read, then refresh ticks
              await _markRead();
            }
          },
        )
        // ── Message updated (is_read toggled → double tick) ───────────────
        .onPostgresChanges(
          event:  PostgresChangeEvent.update,
          schema: 'public',
          table:  'messages',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value:  _conversationId!,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updatedMsg = MessageModel.fromMap(payload.newRecord);
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == updatedMsg.id);
              if (idx != -1) {
                _messages[idx] = updatedMsg;
              }
            });
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Last Seen — DB based
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveMyLastSeen() async {
    if (_conversationId == null) return;
    try {
      final column = _isAdmin ? 'admin_last_seen' : 'client_last_seen';
      await _supabase
          .from('conversations')
          .update({column: DateTime.now().toIso8601String()})
          .eq('id', _conversationId!);
    } catch (e) {
      debugPrint('>>> Save last seen error: $e');
    }
  }

  Future<void> _loadOtherLastSeen() async {
    if (_conversationId == null) return;
    try {
      final data = await _supabase
          .from('conversations')
          .select('client_last_seen, admin_last_seen')
          .eq('id', _conversationId!)
          .single();

      final col = _isAdmin ? 'client_last_seen' : 'admin_last_seen';
      final raw = data[col];
      if (raw != null && mounted) {
        setState(() => _otherLastSeen = DateTime.tryParse(raw.toString()));
      }
    } catch (e) {
      debugPrint('>>> Load last seen error: $e');
    }
  }

  void _subscribeLastSeenRealtime() {
    if (_conversationId == null) return;
    _supabase
        .channel('last_seen_$_conversationId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.update,
          schema: 'public',
          table:  'conversations',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'id',
            value:  _conversationId!,
          ),
          callback: (payload) {
            final col = _isAdmin ? 'client_last_seen' : 'admin_last_seen';
            final raw = payload.newRecord[col];
            if (raw != null && mounted) {
              setState(() => _otherLastSeen = DateTime.tryParse(raw.toString()));
            }
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Presence
  // ─────────────────────────────────────────────────────────────────────────

  void _subscribePresence() {
    if (_conversationId == null) return;
    _presenceChannel?.unsubscribe();

    _presenceChannel = _supabase
        .channel('presence_room_$_conversationId',
            opts: const RealtimeChannelConfig(ack: true))
        .onPresenceSync((_)  => _updateOnlineStatus())
        .onPresenceJoin((_)  => _updateOnlineStatus())
        .onPresenceLeave((_) => _handlePresenceLeave())
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _startHeartbeat();
          }
        });
  }

  bool _isOtherUserOnline() {
    final currentUserId = _supabase.auth.currentUser?.id;
    final presenceList  = _presenceChannel?.presenceState();
    if (presenceList == null || presenceList.isEmpty) return false;

    for (final presence in presenceList) {
      for (final p in presence.presences) {
        final payload = p.payload;
        if (payload['user_id'] != null &&
            payload['user_id'] != currentUserId) {
          return true;
        }
      }
    }
    return false;
  }

  void _updateOnlineStatus() {
    final otherOnline = _isOtherUserOnline();
    if (otherOnline) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (mounted && !_isOnline) {
        setState(() => _isOnline = true);
        // Other user just came online — refresh to pick up ticks they already read
        _refreshMessages();
      }
    }
  }

  void _handlePresenceLeave() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      final otherStillOnline = _isOtherUserOnline();
      if (!otherStillOnline) {
        setState(() => _isOnline = false);
        _loadOtherLastSeen();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mark read
  // 1. Sets conversation-level read flag.
  // 2. Sets is_read=true on all messages sent by the OTHER party.
  // 3. Calls _refreshMessages() so the SENDER's screen immediately
  //    shows double ticks without waiting for a realtime event.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _markRead() async {
    if (_conversationId == null) return;
    try {
      // Conversation-level flag
      if (_isAdmin) {
        await _supabase
            .from('conversations')
            .update({'is_read_admin': true})
            .eq('id', _conversationId!);
      } else {
        await _supabase
            .from('conversations')
            .update({'is_read_client': true})
            .eq('id', _conversationId!);
      }

      // Mark individual messages from the other party as read
      final myId = _supabase.auth.currentUser?.id;
      if (myId != null) {
        await _supabase
            .from('messages')
            .update({'is_read': true})
            .eq('conversation_id', _conversationId!)
            .neq('sender_id', myId)
            .eq('is_read', false);
      }

      // Force a local refresh so our own sent messages flip to double tick
      await _refreshMessages();
    } catch (e) {
      debugPrint('>>> Mark read error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Send message
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _msgCtrl.clear();
    setState(() => _isSending = true);

    try {
      await _supabase.from('messages').insert({
        'conversation_id': _conversationId,
        'sender_id':       _supabase.auth.currentUser?.id,
        'sender_name':     _senderName,
        'sender_role':     _isAdmin ? 'admin' : 'client',
        'content':         text,
        'is_read':         false,
      });
    } catch (e) {
      debugPrint('>>> Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime12h(DateTime dt) {
    final hour   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'am' : 'pm';
    return '$hour:$minute $period';
  }

  String _formatLastSeen(DateTime dt) {
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(dt.year, dt.month, dt.day);
    final timeStr = _formatTime12h(dt);
    if (seenDay == today) return 'last seen today at $timeStr';
    if (seenDay == today.subtract(const Duration(days: 1))) {
      return 'last seen yesterday at $timeStr';
    }
    return 'last seen ${dt.day}/${dt.month}/${dt.year} at $timeStr';
  }

  String get _presenceText {
    if (_isOnline)              return 'Online';
    if (_otherLastSeen != null) return _formatLastSeen(_otherLastSeen!);
    return 'Offline';
  }

  Color get _presenceColor {
    if (_isOnline) return AppColors.accent;
    return const Color(0xFF94A3B8);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isAdmin
        ? (widget.clientName ?? widget.clientEmail ?? 'Client')
        : 'Tokilo Support';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
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
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent.withOpacity(0.25),
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'T',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _presenceColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _presenceText,
                          style: TextStyle(
                            color: _presenceColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading      = true;
                    _errorMessage   = null;
                    _conversationId = null;
                  });
                  _init();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) return _emptyState();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg      = _messages[i];
        final prevMsg  = i > 0 ? _messages[i - 1] : null;
        final showDate = prevMsg == null ||
            _formatDate(msg.createdAt) != _formatDate(prevMsg.createdAt);
        final isMine   = msg.senderId == _supabase.auth.currentUser?.id;
        return Column(
          children: [
            if (showDate) _dateDivider(msg.createdAt),
            _MessageBubble(
              message: msg,
              isMine:  isMine,
              timeStr: _formatTime(msg.createdAt),
            ),
          ],
        );
      },
    );
  }

  Widget _dateDivider(DateTime dt) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_formatDate(dt),
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
          ),
          const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
        ]),
      );

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
            const Text('No messages yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text(
              _isAdmin
                  ? 'Client messages will appear here'
                  : 'Send a message to the Tokilo team',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool         isMine;
  final String       timeStr;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                (message.senderName ?? 'T').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF03404E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMine) ...[
                    Text(
                      message.isAdmin
                          ? 'Tokilo Team'
                          : (message.senderName ?? 'Client'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withOpacity(0.6)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        // ✓  sent  — single grey tick
                        // ✓✓ seen  — double coloured tick
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message.isRead
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}