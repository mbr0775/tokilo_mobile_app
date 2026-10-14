import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Retries use the same identifier until the server acknowledges the message.
class PendingTextMessage {
  final String conversationId;
  final String content;
  final String id;
  PendingTextMessage(this.conversationId, this.content) : id = newMessageId();
}

String newMessageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class ChatRepository {
  final SupabaseClient client;
  ChatRepository(this.client);

  Future<String> openConversation() async {
    final rows = await client
        .rpc('tokilo_open_conversation')
        .timeout(const Duration(seconds: 12));
    return (rows as List).first['id'] as String;
  }

  Future<void> verifyConversation(String id) async {
    final row = await client
        .from('conversations')
        .select('id')
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    if (row == null) throw StateError('Conversation unavailable');
  }

  Future<String> sendText(PendingTextMessage message) async {
    final rows = await client
        .rpc(
          'tokilo_send_message',
          params: {
            'p_conversation_id': message.conversationId,
            'p_message_id': message.id,
            'p_content': message.content,
          },
        )
        .timeout(const Duration(seconds: 15));
    final result = (rows as List).single as Map;
    if (result['id'] != message.id)
      throw StateError('Message not acknowledged');
    return message.id;
  }

  Future<List<Map<String, dynamic>>> messages(
    String id, {
    int limit = 80,
  }) async {
    final rows = await client
        .from('messages')
        .select()
        .eq('conversation_id', id)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit)
        .timeout(const Duration(seconds: 15));
    return Future.wait(
      rows.reversed.map((row) async {
        final result = Map<String, dynamic>.from(row);
        final path = result['attachment_path'];
        if (result['attachment_bucket'] == 'chat-attachments' &&
            path is String) {
          result['attachment_url'] = null;
          try {
            result['attachment_url'] = await client.storage
                .from('chat-attachments')
                .createSignedUrl(path, 1800)
                .timeout(const Duration(seconds: 8));
          } catch (_) {
            /* Leave a recoverable image placeholder. */
          }
        }
        return result;
      }),
    );
  }

  Future<void> readThrough(String conversationId, String messageId) => client
      .rpc(
        'tokilo_read_conversation',
        params: {
          'p_conversation_id': conversationId,
          'p_last_message_id': messageId,
        },
      )
      .timeout(const Duration(seconds: 10));

  Future<String> sendImage({
    required String conversationId,
    required String id,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    if (bytes.length > 10485760 ||
        !{
          'image/jpeg',
          'image/png',
          'image/webp',
          'image/gif',
        }.contains(mimeType)) {
      throw ArgumentError('Choose a JPEG, PNG, WebP or GIF below 10 MB');
    }
    final path = '$userId/$conversationId/${id}_$fileName';
    try {
      await client.storage
          .from('chat-attachments')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, cacheControl: '0'),
          )
          .timeout(const Duration(seconds: 35));
    } on StorageException catch (e) {
      // An interrupted acknowledgement may leave our already-uploaded object.
      if (e.statusCode != '409' && e.error != 'Duplicate') rethrow;
    }
    final rows = await client
        .rpc(
          'tokilo_send_image',
          params: {
            'p_conversation_id': conversationId,
            'p_message_id': id,
            'p_path': path,
            'p_name': fileName,
            'p_mime_type': mimeType,
          },
        )
        .timeout(const Duration(seconds: 15));
    if ((rows as List).single['id'] != id)
      throw StateError('Image not acknowledged');
    return id;
  }
}
