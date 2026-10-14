import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/core/services/account_service.dart';
import 'package:tokilo/features/chat/chat_repository.dart';

const userId = '20000000-0000-4000-8000-000000000001';
const conversationId = '30000000-0000-4000-8000-000000000001';
Future<void> signIn(SupabaseClient client) async {
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token':
          '${base64UrlEncode(utf8.encode('{}'))}.${base64UrlEncode(utf8.encode(jsonEncode({'sub': userId, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature',
      'refresh_token': 'local-test',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'email': 'client@example.test',
        'created_at': '2026-10-13T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
}

SupabaseClient makeClient(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://release-test.supabase.co',
  'fixture-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response(
      response.body,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);
http.Response jsonResponse(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deletion only signs out after a matching successful server acknowledgement',
    () async {
      var reply = <String, Object?>{'success': false};
      final client = makeClient((request) async {
        expect(request.url.host, 'release-test.supabase.co');
        if (request.url.path.endsWith('delete-account')) {
          expect(jsonDecode(request.body), {'confirmation': 'DELETE'});
          return jsonResponse(reply);
        }
        return jsonResponse({});
      });
      addTearDown(client.dispose);
      await signIn(client);
      final service = AccountService(client);
      await expectLater(
        service.deleteCurrentAccount(),
        throwsA(isA<AccountActionException>()),
      );
      expect(client.auth.currentUser?.id, userId);
      reply = {'success': true, 'deleted_user_id': 'another-user'};
      await expectLater(
        service.deleteCurrentAccount(),
        throwsA(isA<AccountActionException>()),
      );
      expect(client.auth.currentUser?.id, userId);
      reply = {'success': true, 'deleted_user_id': userId};
      await service.deleteCurrentAccount();
      expect(client.auth.currentSession, isNull);
    },
  );
  test(
    'a failed device cleanup still clears the confirmed deleted session',
    () async {
      final client = makeClient(
        (_) async => jsonResponse({'success': true, 'deleted_user_id': userId}),
      );
      addTearDown(client.dispose);
      await signIn(client);
      await expectLater(
        AccountService(client).deleteCurrentAccount(
          clearDeviceRegistration: () async {
            throw StateError('local registration failure');
          },
        ),
        throwsStateError,
      );
      expect(client.auth.currentSession, isNull);
    },
  );
  test(
    'retry preserves message ID and rejects mismatched acknowledgements',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = makeClient((request) async {
        final body = Map<String, dynamic>.from(jsonDecode(request.body));
        bodies.add(body);
        if (bodies.length == 1)
          return jsonResponse({'message': 'timeout'}, 503);
        return jsonResponse([
          {'id': body['p_message_id']},
        ]);
      });
      addTearDown(client.dispose);
      final pending = PendingTextMessage(conversationId, 'Keep this draft');
      expect(
        pending.id,
        matches(
          RegExp(r'^[0-9a-f-]{14}4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
        ),
      );
      final repo = ChatRepository(client);
      await expectLater(
        repo.sendText(pending),
        throwsA(isA<PostgrestException>()),
      );
      expect(await repo.sendText(pending), pending.id);
      expect(bodies[0], bodies[1]);
    },
  );
  test('read receipts use an explicit displayed watermark', () async {
    final client = makeClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/tokilo_read_conversation');
      expect(jsonDecode(request.body), {
        'p_conversation_id': conversationId,
        'p_last_message_id': 'last-displayed',
      });
      return jsonResponse(null);
    });
    addTearDown(client.dispose);
    await ChatRepository(client).readThrough(conversationId, 'last-displayed');
  });
  test(
    'image loading uses private signed URLs and keeps failures recoverable',
    () async {
      final client = makeClient((request) async {
        if (request.url.path.startsWith('/rest/v1/messages')) {
          expect(request.url.queryParameters['limit'], '80');
          return jsonResponse([
            {
              'id': 'image',
              'attachment_bucket': 'chat-attachments',
              'attachment_path': '$userId/$conversationId/image.png',
              'attachment_url': 'https://unsafe-old.test/public.png',
            },
          ]);
        }
        expect(
          request.url.path,
          contains('/storage/v1/object/sign/chat-attachments/'),
        );
        return jsonResponse({'message': 'Not authorized'}, 403);
      });
      addTearDown(client.dispose);
      final result = await ChatRepository(client).messages(conversationId);
      expect(result.single['attachment_url'], isNull);
      expect(result.single['attachment_path'], isNotNull);
    },
  );
}
