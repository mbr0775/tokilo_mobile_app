import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/admin/constants/admin_constants.dart';
import 'package:tokilo/features/auth/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://startup-test.supabase.co',
      anonKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  Future<void> checkDestination(WidgetTester tester, String destination) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        for (final path in [
          '/onboarding',
          '/login',
          '/home',
          '/admin/dashboard',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Allow preference I/O to finish without advancing the animation clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(router.routeInformationProvider.value.uri.path, destination);
    expect(find.text(destination), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> restoreUser(String email) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': '00000000-0000-0000-0000-000000000001',
          'aud': 'authenticated',
          'email': email,
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }

  testWidgets('first launch reaches onboarding without a fixed splash delay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await checkDestination(tester, '/onboarding');
  });

  testWidgets('returning signed-out user reaches login immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seen_onboarding': true});
    await checkDestination(tester, '/login');
  });

  testWidgets('restored client session reaches home immediately', (
    tester,
  ) async {
    await restoreUser('client@example.test');
    await checkDestination(tester, '/home');
  });

  testWidgets('restored admin session reaches its dashboard immediately', (
    tester,
  ) async {
    await restoreUser(AdminConstants.adminEmail);
    await checkDestination(tester, '/admin/dashboard');
  });
}
