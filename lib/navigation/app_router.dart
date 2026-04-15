// lib/navigation/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/portal/screens/portal_screen.dart';
import '../features/tools/screens/tools_screen.dart';
import '../features/hub/screens/tokilo_hub_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/cart/screens/checkout_screen.dart';
import '../features/cart/screens/order_success_screen.dart';
import '../features/portfolio/screens/portfolio_screen.dart'; // ← NEW
import '../admin/navigation/admin_router.dart';
import 'bottom_nav_shell.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loc     = state.matchedLocation;

      final isAuthRoute  = loc == '/login' ||
                           loc == '/signup' ||
                           loc == '/forgot-password' ||
                           loc == '/splash';
      final isAdminRoute = loc.startsWith('/admin');

      if (session == null && isAdminRoute) return '/login';

      if (session != null && isAuthRoute && loc != '/splash') {
        return isAdminUser() ? '/admin/dashboard' : '/home';
      }

      if (session != null && isAdminRoute && !isAdminUser()) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Auth ───────────────────────────────────────────────────────────
      GoRoute(path: '/splash',          builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup',          builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // ── Chat (outside shell — own AppBar) ──────────────────────────────
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),

      // ── Portfolio (outside shell — full-screen with own AppBar) ────────
      GoRoute(path: '/portfolio', builder: (_, __) => const PortfolioScreen()), // ← NEW

      // ── Admin routes ───────────────────────────────────────────────────
      ...adminRoutes,

      // ── App shell (with bottom nav) ────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(path: '/home',          builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/portal',        builder: (_, __) => const PortalScreen()),
          GoRoute(path: '/tools',         builder: (_, __) => const ToolsScreen()),
          GoRoute(path: '/marketplace',   builder: (_, __) => const TokiloHubScreen()),
          GoRoute(path: '/hub',           builder: (_, __) => const TokiloHubScreen()),
          GoRoute(path: '/profile',       builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/cart',          builder: (_, __) => const CartScreen()),
          GoRoute(path: '/checkout',      builder: (_, __) => const CheckoutScreen()),
          GoRoute(path: '/order-success', builder: (_, __) => const OrderSuccessScreen()),
        ],
      ),
    ],
  );
}