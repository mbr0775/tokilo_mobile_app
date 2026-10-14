// lib/main.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/constants/app_colors.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/user_presence_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/secure_auth_storage.dart';
import 'core/services/auth_callback_service.dart';
import 'navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  final startupTimer = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final authStorage = SecureAuthStorage(
    namespace: 'tokilo.nsosypdtxdoeiszilpwj',
  );
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: false,
      localStorage: authStorage,
      pkceAsyncStorage: SecurePkceStorage(
        namespace: 'tokilo.nsosypdtxdoeiszilpwj',
      ),
    ),
  );
  AppRouter.clearStoredCompletionSession = authStorage.removePersistedSession;

  runApp(const TokiloApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint(
      '[Startup] First Flutter frame: ${startupTimer.elapsedMilliseconds} ms',
    );
    startupTimer.stop();
  });
}

class TokiloApp extends StatefulWidget {
  const TokiloApp({super.key});

  @override
  State<TokiloApp> createState() => _TokiloAppState();
}

class _TokiloAppState extends State<TokiloApp> with WidgetsBindingObserver {
  final _authMessenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<AuthState>? _authSub;
  Future<void>? _notificationSetup;
  late final AuthCallbackService _authCallbacks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authCallbacks = AuthCallbackService(
      auth: Supabase.instance.client.auth,
      onEmailConfirmation: AppRouter.returnToLogin,
      onError: _showCallbackError,
    )..start();

    // Permission prompts, FCM and presence must never hold the native splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notificationSetup = _initializeNotifications();
      unawaited(UserPresenceService.instance.start());
    });

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;

      if (session != null && !AppRouter.isReturningToLogin) {
        unawaited(UserPresenceService.instance.start());
        unawaited(_registerPushToken());
        if (Firebase.apps.isNotEmpty)
          PushNotificationService.instance.openPendingConversation();
      } else {
        unawaited(UserPresenceService.instance.stop());
      }
    }, onError: _showCallbackError);
  }

  void _showCallbackError(Object _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authMessenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'This confirmation, sign-in or reset link could not be used. Sign in again or request a new link.',
          ),
        ),
      );
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      PushNotificationService.instance.onConversationOpen = (id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Supabase.instance.client.auth.currentSession != null) {
            AppRouter.router.push('/chat?conversation=$id');
          }
        });
      };
      await PushNotificationService.instance.init();
    } catch (error) {
      // Push is optional: a device/network failure must not prevent app access.
      debugPrint('Notification setup unavailable: $error');
    }
  }

  Future<void> _registerPushToken() async {
    // Auth can emit its initial session before the first frame/Firebase setup.
    final setup = _notificationSetup;
    if (setup == null || AppRouter.isReturningToLogin) return;
    await setup;
    if (!mounted || Firebase.apps.isEmpty) return;
    await PushNotificationService.instance.registerToken();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    unawaited(_authCallbacks.dispose());
    if (Firebase.apps.isNotEmpty)
      unawaited(PushNotificationService.instance.dispose());
    unawaited(UserPresenceService.instance.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(UserPresenceService.instance.start());
      unawaited(_registerPushToken());
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      unawaited(UserPresenceService.instance.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: _authMessenger,
      title: 'Tokilo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
