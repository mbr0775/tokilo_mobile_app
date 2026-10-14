// lib/features/chat/models/chat_models.dart

class ConversationModel {
  final String id;
  final String clientId;
  final String? clientName;
  final String? clientEmail;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final bool isReadAdmin;
  final bool isReadClient;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.clientId,
    this.clientName,
    this.clientEmail,
    this.lastMessage,
    required this.lastMessageAt,
    required this.isReadAdmin,
    required this.isReadClient,
    required this.createdAt,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> m) {
    return ConversationModel(
      id: m['id']?.toString() ?? '',
      clientId: m['client_id']?.toString() ?? '',
      clientName: m['client_name']?.toString(),
      clientEmail: m['client_email']?.toString(),
      lastMessage: m['last_message']?.toString(),
      lastMessageAt:
          DateTime.tryParse(m['last_message_at']?.toString() ?? '') ??
          DateTime.now(),
      isReadAdmin: m['is_read_admin'] == true,
      isReadClient: m['is_read_client'] == true,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String senderRole;
  final String content;
  final bool isRead;
  final DateTime? seenAt;
  final String messageType;
  final String? attachmentUrl;
  final String? attachmentPath;
  final String? attachmentName;
  final String? attachmentMimeType;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.senderRole,
    required this.content,
    required this.isRead,
    this.seenAt,
    required this.messageType,
    this.attachmentUrl,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentMimeType,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m) {
    return MessageModel(
      id: m['id']?.toString() ?? '',
      conversationId: m['conversation_id']?.toString() ?? '',
      senderId: m['sender_id']?.toString() ?? '',
      senderName: m['sender_name']?.toString(),
      senderRole: m['sender_role']?.toString() ?? 'client',
      content: m['content']?.toString() ?? '',
      isRead: m['is_read'] == true,
      seenAt: DateTime.tryParse(m['seen_at']?.toString() ?? ''),
      messageType: m['message_type']?.toString() ?? 'text',
      attachmentUrl: m['attachment_url']?.toString(),
      attachmentPath: m['attachment_path']?.toString(),
      attachmentName: m['attachment_name']?.toString(),
      attachmentMimeType: m['attachment_mime_type']?.toString(),
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isAdmin => senderRole == 'admin';

  bool get isClient => senderRole == 'client';

  bool get isSeen => isRead || seenAt != null;

  bool get isImage => messageType == 'image';
}
