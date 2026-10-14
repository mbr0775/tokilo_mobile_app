import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/core/services/google_auth_service.dart';
import 'package:tokilo/features/auth/screens/forgot_password_screen.dart';
import 'package:tokilo/features/auth/screens/reset_password_screen.dart';
import 'package:tokilo/navigation/auth_router_refresh.dart';

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  bool failUpdate = false;
  final user = {
    'id': '21000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'email': 'client@example.technology',
    'created_at': '2026-10-13T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://password-test.supabase.co',
      anonKey: 'fixture-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: MemoryPkce(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'password-test.supabase.co');
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/user')
                ? failUpdate
                      ? {'code': 'session_expired', 'msg': 'Recovery expired'}
                      : user
                : {},
          ),
          failUpdate && request.method == 'PUT' ? 401 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    failUpdate = false;
  });

  testWidgets(
    'reset email accepts business domains and returns to the release app',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.enterText(
        find.byType(TextFormField),
        'client@example.technology',
      );
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();
      final request = requests.singleWhere(
        (r) => r.url.path.endsWith('/recover'),
      );
      expect(
        request.url.queryParameters['redirect_to'],
        GoogleAuthService.redirectUrl,
      );
      expect(jsonDecode(request.body)['email'], 'client@example.technology');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('weak or mismatched passwords never reach the backend', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'different');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('The passwords don’t match.'), findsOneWidget);
    expect(requests, isEmpty);
  });
  testWidgets('expired recovery cannot navigate or falsely report success', (
    tester,
  ) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': user,
      }),
    );
    failUpdate = true;
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(onUpdated: () async => completed = true),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Fixture-password-123',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Fixture-password-123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(
      find.textContaining('Could not update your password'),
      findsOneWidget,
    );
    failUpdate = false;
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(
      find.textContaining('Your password has been updated.'),
      findsOneWidget,
    );
    expect(requests.where((r) => r.method == 'PUT'), hasLength(2));
    expect(tester.takeException(), isNull);
  });
  test('recovery routing survives token refresh until completed', () async {
    final events = StreamController<AuthState>(sync: true);
    final refresh = AuthRouterRefresh(events.stream);
    events.add(AuthState(AuthChangeEvent.passwordRecovery, null));
    expect(refresh.passwordRecoveryActive, isTrue);
    events.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
    expect(refresh.passwordRecoveryActive, isTrue);
    refresh.completeRecovery();
    expect(refresh.passwordRecoveryActive, isFalse);
    refresh.dispose();
    await events.close();
  });
}
