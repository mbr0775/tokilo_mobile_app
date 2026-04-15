// lib/admin/navigation/admin_router.dart
// UPDATED: Added /admin/showcase route

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/admin_constants.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_portfolio_screen.dart';
import '../screens/admin_products_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_settings_screen.dart';
import '../screens/admin_home_components_screen.dart';
import '../screens/admin_projects_screen.dart';
import '../screens/admin_showcase_screen.dart';          // ← NEW
import '../../features/chat/screens/admin_conversations_screen.dart';

bool isAdminUser() {
  final email = Supabase.instance.client.auth.currentUser?.email ?? '';
  return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
}

List<RouteBase> get adminRoutes => [
  GoRoute(path: '/admin/dashboard',
      builder: (_, __) => const AdminDashboardScreen()),
  GoRoute(path: '/admin/portfolio',
      builder: (_, __) => const AdminPortfolioScreen()),
  GoRoute(path: '/admin/products',
      builder: (_, __) => const AdminProductsScreen()),
  GoRoute(path: '/admin/users',
      builder: (_, __) => const AdminUsersScreen()),
  GoRoute(path: '/admin/settings',
      builder: (_, __) => const AdminSettingsScreen()),
  GoRoute(path: '/admin/home-components',
      builder: (_, __) => const AdminHomeComponentsScreen()),
  GoRoute(path: '/admin/projects',
      builder: (_, __) => const AdminProjectsScreen()),
  GoRoute(path: '/admin/messages',
      builder: (_, __) => const AdminConversationsScreen()),
  GoRoute(path: '/admin/showcase',                       // ← NEW
      builder: (_, __) => const AdminShowcaseScreen()),
];