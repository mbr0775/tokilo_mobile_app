// lib/navigation/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';

import '../features/feed/screens/feed_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/portal/screens/portal_screen.dart';
import '../features/projects/screens/project_pricing_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/portfolio/screens/portfolio_screen.dart';

import '../admin/navigation/admin_router.dart';
import 'bottom_nav_shell.dart';
import 'auth_router_refresh.dart';
import '../core/services/auth_callback_service.dart';

class AppRouter {
  static Future<void> Function()? clearStoredCompletionSession;
  static bool get isReturningToLogin => _authRefresh.returningToLogin;

  static Future<void> completePasswordRecovery() => returnToLogin();

  static Future<void> returnToLogin() async {
    _authRefresh.beginReturnToLogin();
    await clearCompletionSession(Supabase.instance.client.auth);
    await clearStoredCompletionSession?.call();
    _authRefresh.completeReturnToLogin();
    router.go('/login');
  }

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final AuthRouterRefresh _authRefresh = AuthRouterRefresh(
    Supabase.instance.client.auth.onAuthStateChange,
  );

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _authRefresh,

    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      if (_authRefresh.returningToLogin) {
        return loc == '/login' ? null : '/login';
      }
      if (session != null && _authRefresh.passwordRecoveryActive) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (loc == '/reset-password' &&
          (session == null || !_authRefresh.passwordRecoveryActive)) {
        return session == null
            ? '/login'
            : (isAdminUser() ? '/admin/dashboard' : '/feed');
      }

      final bool isAuthRoute =
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password' ||
          loc == '/splash' ||
          loc == '/onboarding';

      final bool isAdminRoute = loc.startsWith('/admin');

      // Allow splash and onboarding to load normally.
      // Your SplashScreen / OnboardingScreen can handle their own timing.
      if (loc == '/splash' || loc == '/onboarding') {
        return null;
      }

      // If user is not logged in, block private pages.
      if (session == null && !isAuthRoute) {
        return '/splash';
      }

      // If user is not logged in, block admin pages.
      if (session == null && isAdminRoute) {
        return '/splash';
      }

      // If logged in and trying to access auth screens,
      // redirect to correct dashboard.
      if (session != null && isAuthRoute) {
        return isAdminUser() ? '/admin/dashboard' : '/feed';
      }

      // If non-admin tries admin page, redirect to Feed.
      if (session != null && isAdminRoute && !isAdminUser()) {
        return '/feed';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      // Auth / launch routes
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // Chat opens outside bottom navigation.
      GoRoute(
        path: '/chat',
        builder: (_, state) {
          final id = state.uri.queryParameters['conversation'];
          final valid =
              id != null &&
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false,
              ).hasMatch(id);
          return ChatScreen(conversationId: valid ? id : null);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Portfolio / project showcase opens outside bottom navigation.
      // Feed cards can navigate here using context.go('/portfolio').
      GoRoute(path: '/portfolio', builder: (_, __) => const PortfolioScreen()),

      // Admin routes.
      ...adminRoutes,

      // Main user app with bottom navigation.
      // Bottom order:
      // 1. Feed
      // 2. Home
      // 3. Requests
      // 4. Prices
      // 5. Profile
      ShellRoute(
        builder: (_, __, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/portal', builder: (_, __) => const PortalScreen()),
          GoRoute(
            path: '/marketplace',
            builder: (_, __) => const ProjectPricingScreen(),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
