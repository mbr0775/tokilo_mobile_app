import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/core/services/auth_callback_service.dart';
import 'package:tokilo/core/services/google_auth_service.dart';
import 'package:tokilo/navigation/app_router.dart';
import 'package:tokilo/features/auth/widgets/gradient_button.dart';

class CallbackPkceMemory extends GotrueAsyncStorage {
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
  final errors = <Object>[];
  final pkce = CallbackPkceMemory();
  bool failExchange = false;
  bool signupWithSession = false;
  bool failPasswordUpdate = false;
  int storedSessionClears = 0;
  final user = <String, dynamic>{
    'id': '21000000-0000-4000-8000-000000000011',
    'aud': 'authenticated',
    'email': 'completion@example.test',
    'email_confirmed_at': '2026-10-14T00:00:00Z',
    'created_at': '2026-10-14T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{'full_name': 'Completion fixture'},
  };
  late AuthCallbackService callbacks;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'seen_onboarding': true});
    await Supabase.initialize(
      url: 'https://completion-test.supabase.co',
      anonKey: 'fixture-public-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: pkce,
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'completion-test.supabase.co');
        Object body = {};
        int status = 200;
        if (request.url.path.endsWith('/token')) {
          if (failExchange) {
            status = 400;
            body = {'msg': 'Expired callback', 'code': 'invalid_grant'};
          } else {
            body = {
              'access_token': 'fixture-access',
              'refresh_token': 'fixture-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': user,
            };
          }
        } else if (request.url.path.endsWith('/user')) {
          if (request.method == 'PUT' && failPasswordUpdate) {
            status = 401;
            body = {'msg': 'Recovery expired', 'code': 'session_expired'};
          } else {
            body = user;
          }
        } else if (request.url.path.endsWith('/signup')) {
          body = signupWithSession
              ? {
                  'access_token': 'fixture-access',
                  'refresh_token': 'fixture-refresh',
                  'expires_in': 3600,
                  'token_type': 'bearer',
                  'user': user,
                }
              : {
                  'user': {...user, 'email_confirmed_at': null},
                };
        } else if (request.url.path.contains('/rest/v1/')) {
          body = <Object>[];
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async {
    AppRouter.router.dispose();
    await Supabase.instance.dispose();
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    requests.clear();
    errors.clear();
    failExchange = false;
    signupWithSession = false;
    failPasswordUpdate = false;
    storedSessionClears = 0;
    AppRouter.clearStoredCompletionSession = () async {
      storedSessionClears++;
    };
    callbacks = AuthCallbackService(
      auth: Supabase.instance.client.auth,
      onEmailConfirmation: AppRouter.returnToLogin,
      onError: errors.add,
    );
    AppRouter.router.go('/login');
  });
  tearDown(() => callbacks.dispose());

  Future<void> renderRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: AppRouter.router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitSignup(WidgetTester tester) async {
    AppRouter.router.go('/signup');
    await renderRouter(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Completion fixture');
    await tester.enterText(fields.at(2), 'completion@example.test');
    await tester.enterText(fields.at(4), 'Fixture-signup-password-123');
    await tester.enterText(fields.at(5), 'Fixture-signup-password-123');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    final submit = find.widgetWithText(GradientButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'registration requests the confirmation-only callback and stays at Login',
    (tester) async {
      await submitSignup(tester);
      final request = requests.singleWhere(
        (r) => r.url.path.endsWith('/signup'),
      );
      expect(
        request.url.queryParameters['redirect_to'],
        AuthCallbackUrls.mobileSignup,
      );
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(Supabase.instance.client.auth.currentSession, isNull);
    },
  );

  testWidgets(
    'registration requires Login even when the backend returns an immediate session',
    (tester) async {
      signupWithSession = true;
      final locations = <String>[];
      void recordLocation() => locations.add(
        AppRouter.router.routeInformationProvider.value.uri.path,
      );
      AppRouter.router.routeInformationProvider.addListener(recordLocation);
      await submitSignup(tester);
      AppRouter.router.routeInformationProvider.removeListener(recordLocation);
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(locations, isNot(contains('/feed')));
      expect(
        requests.where((r) => r.url.path.endsWith('/logout')),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'email confirmation stays at Login without exchanging a sign-in code',
    (tester) async {
      await renderRouter(tester);
      await tester.runAsync(
        () => callbacks.handle(
          Uri.parse('${AuthCallbackUrls.mobileSignup}?code=confirmation-code'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(requests.where((r) => r.url.path.endsWith('/token')), isEmpty);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(errors, isEmpty);
    },
  );

  testWidgets(
    'recovery saves password, clears the temporary session and returns to Login',
    (tester) async {
      await renderRouter(tester);
      await Supabase.instance.client.auth.resetPasswordForEmail(
        'completion@example.test',
        redirectTo: GoogleAuthService.redirectUrl,
      );
      await tester.runAsync(
        () => callbacks.handle(
          Uri.parse('${GoogleAuthService.redirectUrl}?code=recovery-code'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/reset-password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'New-fixture-password-123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'New-fixture-password-123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(
        requests.where(
          (r) => r.method == 'PUT' && r.url.path.endsWith('/user'),
        ),
        hasLength(1),
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/logout')),
        hasLength(1),
      );
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(
        find.textContaining('Sign in with your new password'),
        findsOneWidget,
      );
      expect(storedSessionClears, 1);
      expect(errors, isEmpty);
    },
  );

  testWidgets(
    'a failed password update stays on reset and never completes logout',
    (tester) async {
      await renderRouter(tester);
      await Supabase.instance.client.auth.resetPasswordForEmail(
        'completion@example.test',
      );
      await tester.runAsync(
        () => callbacks.handle(
          Uri.parse('${GoogleAuthService.redirectUrl}?code=failed-update-code'),
        ),
      );
      await tester.pumpAndSettle();
      failPasswordUpdate = true;
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'New-fixture-password-123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'New-fixture-password-123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/reset-password',
      );
      expect(requests.where((r) => r.url.path.endsWith('/logout')), isEmpty);
      expect(storedSessionClears, 0);
      expect(
        find.textContaining('Could not update your password'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sign in with your new password'),
        findsNothing,
      );
    },
  );

  testWidgets('Google OAuth still establishes a session and reaches Feed', (
    tester,
  ) async {
    await renderRouter(tester);
    await Supabase.instance.client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: GoogleAuthService.redirectUrl,
    );
    await tester.runAsync(
      () => callbacks.handle(
        Uri.parse('${GoogleAuthService.redirectUrl}?code=google-code'),
      ),
    );
    await tester.pumpAndSettle();
    expect(AppRouter.router.routeInformationProvider.value.uri.path, '/feed');
    expect(Supabase.instance.client.auth.currentSession, isNotNull);
    expect(requests.where((r) => r.url.path.endsWith('/logout')), isEmpty);
    expect(errors, isEmpty);
  });

  testWidgets(
    'expired callbacks keep Login and never report successful confirmation',
    (tester) async {
      await renderRouter(tester);
      await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );
      failExchange = true;
      await tester.runAsync(
        () => callbacks.handle(
          Uri.parse('${GoogleAuthService.redirectUrl}?code=expired-code'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(errors, hasLength(1));
      await tester.runAsync(
        () => callbacks.handle(
          Uri.parse(
            '${AuthCallbackUrls.mobileSignup}#error=access_denied&error_description=Expired',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/login',
      );
      expect(errors, hasLength(2));
      expect(find.textContaining('Email verified'), findsNothing);
    },
  );
}
