// lib/features/chat/screens/chat_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/constants/admin_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../models/chat_models.dart';
import '../chat_repository.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? clientName;
  final String? clientEmail;

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
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late final ChatRepository _repository = ChatRepository(_supabase);
  PendingTextMessage? _pendingText;
  XFile? _pendingImage;
  String? _pendingImageId;
  int _messageLimit = 80;
  bool _hasEarlier = false;
  bool _loadingEarlier = false;
  String? _lastReadId;

  bool get _viewingLatest =>
      mounted &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      _scrollCtrl.hasClients &&
      _scrollCtrl.position.extentAfter < 48;

  List<MessageModel> _messages = [];
  String? _conversationId;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  bool _isUploadingAttachment = false;

  String? _errorMessage;

  bool _otherOnline = false;
  DateTime? _otherLastSeen;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _conversationChannel;
  RealtimeChannel? _statusChannel;

  Timer? _uiRefreshTimer;
  Timer? _reloadDebounceTimer;

  bool get _isAdmin {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  bool get _isBusy => _isSending || _isUploadingAttachment;

  String get _appBarTitle {
    if (_isAdmin) {
      return widget.clientName ?? widget.clientEmail ?? 'Client Chat';
    }
    return 'Tokilo Support';
  }

  String get _defaultSubtitle {
    if (_isAdmin) {
      return widget.clientEmail ?? 'Client conversation';
    }
    return 'Private support conversation';
  }

  String get _statusSubtitle {
    if (_otherOnline) return 'Online';
    if (_otherLastSeen == null) return _defaultSubtitle;
    return 'Last seen ${_formatTime(_otherLastSeen!)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationId = widget.conversationId;
    _scrollCtrl.addListener(_onScroll);
    _initChat();

    _uiRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();

    _uiRefreshTimer?.cancel();
    _reloadDebounceTimer?.cancel();

    _messageChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();
    _statusChannel?.unsubscribe();

    super.dispose();
  }

  Future<void> _initChat() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      if (_conversationId == null || _conversationId!.isEmpty) {
        _conversationId = await _getOrCreateClientConversation();
      }

      await _repository.verifyConversation(_conversationId!);
      await _loadMessages(showLoader: false);
      await _loadOtherStatus();

      _subscribeRealtime();
      await _subscribeOtherStatus();

      if (!mounted) return;
      setState(() => _isLoading = false);

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Check your connection and try again.';
      });
    }
  }

  Future<String> _getOrCreateClientConversation() =>
      _repository.openConversation();

  void _onScroll() {
    if (_viewingLatest) unawaited(_markConversationRead());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_safeRefresh());
  }

  Future<void> _loadMessages({
    required bool showLoader,
    bool preservePosition = false,
  }) async {
    final id = _conversationId;
    if (id == null || id.isEmpty) return;
    final follow = !_scrollCtrl.hasClients || _viewingLatest;
    if (showLoader && mounted) setState(() => _isRefreshing = true);
    try {
      final data = await _repository.messages(id, limit: _messageLimit);
      if (!mounted) return;
      setState(() {
        _messages = data.map(MessageModel.fromMap).toList();
        _hasEarlier = data.length == _messageLimit;
      });
      if (follow && !preservePosition) _scrollToBottom();
    } finally {
      if (mounted && showLoader) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadEarlier() async {
    if (_loadingEarlier) return;
    final offset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    final extent = _scrollCtrl.hasClients
        ? _scrollCtrl.position.maxScrollExtent
        : 0.0;
    setState(() => _loadingEarlier = true);
    _messageLimit += 80;
    try {
      await _loadMessages(showLoader: false, preservePosition: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(
            (offset + _scrollCtrl.position.maxScrollExtent - extent).clamp(
              0.0,
              _scrollCtrl.position.maxScrollExtent,
            ),
          );
        }
      });
    } catch (_) {
      _messageLimit -= 80;
      _showSnack('Earlier messages could not load. Try again.');
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  Future<void> _markConversationRead() async {
    final id = _conversationId;
    if (id == null || _messages.isEmpty || !_viewingLatest) return;
    final watermark = _messages.last.id;
    if (_lastReadId == watermark) return;
    _lastReadId = watermark;
    try {
      await _repository.readThrough(id, watermark);
    } catch (_) {
      if (_lastReadId == watermark) _lastReadId = null;
    }
  }

  Future<String?> _getOtherUserId() async {
    final id = _conversationId;
    if (id == null || id.isEmpty) return null;

    if (_isAdmin) {
      final conversation = await _supabase
          .from('conversations')
          .select('client_id')
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      return conversation?['client_id']?.toString();
    }

    final adminStatus = await _supabase
        .from('user_status')
        .select('user_id')
        .eq('email', AdminConstants.adminEmail)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));

    return adminStatus?['user_id']?.toString();
  }

  Future<void> _loadOtherStatus() async {
    try {
      final otherId = await _getOtherUserId();
      if (otherId == null) return;

      final data = await _supabase
          .from('user_status')
          .select()
          .eq('user_id', otherId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (data == null || !mounted) return;

      setState(() {
        _otherOnline = data['is_online'] == true;
        _otherLastSeen = DateTime.tryParse(
          data['last_seen_at']?.toString() ?? '',
        );
      });
    } catch (_) {
      // Presence should not break chat.
    }
  }

  void _scheduleRealtimeReload() {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _safeRefresh();
    });
  }

  Future<void> _safeRefresh() async {
    try {
      await _loadMessages(showLoader: false);
      await _markConversationRead();
      await _loadOtherStatus();
    } catch (_) {}
  }

  void _subscribeRealtime() {
    final id = _conversationId;
    if (id == null || id.isEmpty) return;

    _messageChannel?.unsubscribe();
    _conversationChannel?.unsubscribe();

    _messageChannel = _supabase
        .channel('chat_messages_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: id,
          ),
          callback: (_) => _scheduleRealtimeReload(),
        )
        .subscribe();

    _conversationChannel = _supabase
        .channel('chat_conversation_$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (_) => _scheduleRealtimeReload(),
        )
        .subscribe();
  }

  Future<void> _subscribeOtherStatus() async {
    try {
      final otherId = await _getOtherUserId();
      if (otherId == null) return;

      _statusChannel?.unsubscribe();

      _statusChannel = _supabase
          .channel('chat_user_status_$otherId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_status',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: otherId,
            ),
            callback: (_) => _loadOtherStatus(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _sendPushForInsertedMessage(String messageId) async {
    if (!_isAdmin) return;
    try {
      await _supabase.functions
          .invoke('send-chat-push', body: {'message_id': messageId})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      /* Message delivery is independent of push delivery. */
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    final id = _conversationId;
    if (text.isEmpty || _isBusy || id == null) return;
    if (text.length > 4000) {
      _showSnack('Keep messages below 4,000 characters.');
      return;
    }
    if (_pendingText?.content != text || _pendingText?.conversationId != id) {
      _pendingText = PendingTextMessage(id, text);
    }
    setState(() => _isSending = true);
    try {
      final sentId = await _repository.sendText(_pendingText!);
      _pendingText = null;
      if (!mounted) return;
      if (_msgCtrl.text.trim() == text) _msgCtrl.clear();
      unawaited(_sendPushForInsertedMessage(sentId));
      await _safeRefresh();
      _scrollToBottom();
    } catch (_) {
      _showSnack(
        'Message was not confirmed. Your draft is kept; tap send to retry.',
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isBusy) return;
    try {
      final image =
          _pendingImage ??
          await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 82,
            maxWidth: 1600,
          );
      if (image == null || !mounted) return;
      _pendingImage = image;
      _pendingImageId ??= newMessageId();
      await _sendImageMessage(image);
    } catch (_) {
      _showSnack('Image could not be selected. Try again.');
    }
  }

  String _getMimeType(String fileName, String? pickerMimeType) {
    if (pickerMimeType != null && pickerMimeType.trim().isNotEmpty) {
      return pickerMimeType;
    }

    final ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  String _sanitizeFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();

    if (sanitized.isEmpty || sanitized == '_') {
      return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }

    return sanitized;
  }

  Future<void> _sendImageMessage(XFile image) async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _isUploadingAttachment = true);
    try {
      final name = _sanitizeFileName(image.name);
      final sentId = await _repository.sendImage(
        conversationId: id,
        id: _pendingImageId!,
        fileName: name,
        mimeType: _getMimeType(name, image.mimeType),
        bytes: await image.readAsBytes(),
      );
      _pendingImage = null;
      _pendingImageId = null;
      if (!mounted) return;
      unawaited(_sendPushForInsertedMessage(sentId));
      await _safeRefresh();
      _scrollToBottom();
    } on ArgumentError {
      _pendingImage = null;
      _pendingImageId = null;
      _showSnack('Choose a JPEG, PNG, WebP or GIF image below 10 MB.');
    } catch (_) {
      _showSnack(
        'Image was not confirmed. Tap attach to retry the same image.',
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;

      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        unawaited(_markConversationRead());
        return;
      }
      _scrollCtrl
          .animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (mounted) unawaited(_markConversationRead());
          });
    });
  }

  void _safeBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    if (_isAdmin) {
      context.go('/admin/dashboard');
    } else {
      context.go('/feed');
    }
  }

  Future<void> _retry() async {
    await _initChat();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatMessageTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _safeBack,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE7F2F1),
              foregroundColor: AppColors.primary,
              child: Text(
                _isAdmin ? 'C' : 'T',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appBarTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: _otherOnline
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _isRefreshing
                ? null
                : () async {
                    try {
                      await _loadMessages(showLoader: true);
                      await _markConversationRead();
                      await _loadOtherStatus();
                    } catch (_) {
                      _showSnack('Refresh failed. Try again.');
                    }
                  },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? _ErrorState(
              message: 'Could not open chat.\n$_errorMessage',
              onRetry: _retry,
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const _EmptyMessages()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () async {
                            await _loadMessages(showLoader: false);
                            await _markConversationRead();
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            itemCount: _messages.length + (_hasEarlier ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_hasEarlier && index == 0) {
                                return TextButton(
                                  onPressed: _loadingEarlier
                                      ? null
                                      : _loadEarlier,
                                  child: Text(
                                    _loadingEarlier
                                        ? 'Loading…'
                                        : 'Load earlier messages',
                                  ),
                                );
                              }
                              final message =
                                  _messages[index - (_hasEarlier ? 1 : 0)];
                              final mine =
                                  message.senderId ==
                                  _supabase.auth.currentUser?.id;

                              return _MessageBubble(
                                message: message,
                                isMine: mine,
                                timeLabel: _formatMessageTime(
                                  message.createdAt,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                _ChatInputBar(
                  controller: _msgCtrl,
                  busy: _isBusy,
                  isSending: _isSending,
                  isUploading: _isUploadingAttachment,
                  onSend: _sendMessage,
                  onPickImage: _pickAndSendImage,
                ),
              ],
            ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final bool isSending;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _ChatInputBar({
    required this.controller,
    required this.busy,
    required this.isSending,
    required this.isUploading,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach image',
            onPressed: busy ? null : onPickImage,
            icon: isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                  ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              enabled: !busy,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message Tokilo…',
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                if (!busy) onSend();
              },
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: busy ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
            ),
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final String timeLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? const Color(0xFFDDEFEA) : AppColors.surface;
    const textColor = AppColors.textPrimary;
    final metaColor = AppColors.textSecondary;
    final bool isSeen = message.isRead || message.seenAt != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.fromLTRB(
          message.isImage ? 6 : 14,
          message.isImage ? 6 : 10,
          message.isImage ? 6 : 14,
          8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && message.senderName != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: message.isImage ? 6 : 0,
                  right: message.isImage ? 6 : 0,
                  top: message.isImage ? 4 : 0,
                ),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    color: metaColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
            if (message.isImage && message.attachmentUrl != null)
              _ChatImageAttachment(imageUrl: message.attachmentUrl!)
            else if (message.isImage)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Image unavailable. Refresh to try again.'),
              )
            else
              Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.5,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 5),
            Padding(
              padding: EdgeInsets.only(
                left: message.isImage ? 6 : 0,
                right: message.isImage ? 6 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: metaColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                      color: isSeen
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 15,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatImageAttachment extends StatelessWidget {
  final String imageUrl;

  const _ChatImageAttachment({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImagePreview(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: Colors.black.withOpacity(0.04),
          child: Image.network(
            imageUrl,
            width: 230,
            height: 260,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const SizedBox(
                width: 230,
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) {
              return Container(
                width: 230,
                height: 150,
                padding: const EdgeInsets.all(16),
                color: AppColors.background,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textHint,
                      size: 34,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Image unavailable',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          color: Colors.white,
                          child: const Text('Could not load image'),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 76,
              color: AppColors.textHint,
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message or image to start the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              'Chat Error',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
