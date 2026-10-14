import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/core/services/google_auth_service.dart';
import 'package:tokilo/features/auth/screens/signup_screen.dart';
import 'package:tokilo/features/auth/widgets/google_sign_in_button.dart';
import 'package:tokilo/navigation/auth_router_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://google-auth-test.supabase.co',
      anonKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  tearDown(() => messenger.setMockMethodCallHandler(launcherChannel, null));
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'Google OAuth launches externally with the app callback and PKCE',
    () async {
      MethodCall? launch;
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        launch = call;
        return true;
      });
      expect(await GoogleAuthService.signIn(), isTrue);
      expect(launch?.method, 'launch');
      final arguments = launch!.arguments as Map;
      final uri = Uri.parse(arguments['url'] as String);
      expect(uri.host, 'google-auth-test.supabase.co');
      expect(uri.path, '/auth/v1/authorize');
      expect(uri.queryParameters['provider'], 'google');
      expect(uri.queryParameters['redirect_to'], GoogleAuthService.redirectUrl);
      expect(uri.queryParameters['prompt'], 'select_account');
      expect(uri.queryParameters['code_challenge'], isNotEmpty);
      expect(uri.queryParameters['code_challenge_method'], 's256');
      expect(arguments['useWebView'], isFalse);
      expect(arguments['useSafariVC'], isFalse);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    },
  );

  testWidgets('repeated taps launch only once and returning allows a retry', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var launches = 0;
    final busyStates = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(
            signIn: () {
              launches++;
              return pending.future;
            },
            onBusyChanged: busyStates.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton));
    expect(launches, 1);
    expect(find.text('Opening Google...'), findsOneWidget);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(busyStates, [true, false]);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'browser launch failure displays an error and restores the button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GoogleSignInButton(signIn: () async => false)),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open Google sign-in. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets(
    'signup requires consent but Google does not validate the email form',
    (tester) async {
      var launches = 0;
      messenger.setMockMethodCallHandler(launcherChannel, (call) async {
        launches++;
        return true;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: const SignupScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );
      await tester.ensureVisible(find.byType(GoogleSignInButton));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(
        find.text('Please accept the Terms & Conditions to continue.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.byType(GoogleSignInButton));
      await tester.tap(find.text('Continue with Google'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(launches, 1);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    },
  );

  testWidgets(
    'signup fits a narrow screen with large text and the keyboard visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: const SignupScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(
        find.byType(TextFormField).last,
        'Fixture-password',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a completed OAuth session refreshes routing without another tap',
    (tester) async {
      final changes = StreamController<AuthState>();
      final refresh = AuthRouterRefresh(changes.stream);
      var signedIn = false;
      final router = GoRouter(
        initialLocation: '/login',
        refreshListenable: refresh,
        redirect: (_, _) => signedIn ? '/feed' : null,
        routes: [
          for (final path in ['/login', '/feed'])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text(path)),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('/login'), findsOneWidget);
      changes.addError(const AuthException('access_denied'));
      await tester.pump();
      expect(find.text('/login'), findsOneWidget);
      signedIn = true;
      changes.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();
      expect(find.text('/feed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      refresh.dispose();
      unawaited(changes.close());
      await tester.pump();
    },
  );
}
