// lib/features/chat/models/chat_models.dart

class ConversationModel {
  final String   id;
  final String   clientId;
  final String?  clientName;
  final String?  clientEmail;
  final String?  lastMessage;
  final DateTime lastMessageAt;
  final bool     isReadAdmin;
  final bool     isReadClient;
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
      id:            m['id']              ?? '',
      clientId:      m['client_id']       ?? '',
      clientName:    m['client_name'],
      clientEmail:   m['client_email'],
      lastMessage:   m['last_message'],
      lastMessageAt: DateTime.tryParse(m['last_message_at'] ?? '') ?? DateTime.now(),
      isReadAdmin:   m['is_read_admin']   ?? false,
      isReadClient:  m['is_read_client']  ?? false,
      createdAt:     DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class MessageModel {
  final String   id;
  final String   conversationId;
  final String   senderId;
  final String?  senderName;
  final String   senderRole;
  final String   content;
  final bool     isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.senderRole,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> m) {
    return MessageModel(
      id:             m['id']              ?? '',
      conversationId: m['conversation_id'] ?? '',
      senderId:       m['sender_id']       ?? '',
      senderName:     m['sender_name'],
      senderRole:     m['sender_role']     ?? 'client',
      content:        m['content']         ?? '',
      isRead:         m['is_read']         ?? false,
      createdAt:      DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isAdmin => senderRole == 'admin';
}
