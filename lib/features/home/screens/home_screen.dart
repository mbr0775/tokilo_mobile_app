// lib/features/home/screens/home_screen.dart
//
// UPDATED: Replaced HomeProjectsSection with HomeShowcaseSection
// which shows both the public project showcase carousel AND
// the user's own projects in one unified section.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/notifications/notification_store.dart';
import '../../../admin/constants/admin_constants.dart';

// ── Component imports ─────────────────────────────────────────────────────────
import 'components/home_hero_section.dart';
import 'components/home_admin_banner.dart';
import 'components/home_features_section.dart';
import 'components/home_services_section.dart';
import 'components/home_products_section.dart';
import 'components/home_showcase_section.dart';   // ← REPLACES home_projects_section
import 'components/home_promos_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    NotificationStore.instance.init();
  }

  // ── User helpers ──────────────────────────────────────────────────────────────

  String get _userName {
    final meta = _supabase.auth.currentUser?.userMetadata;
    return meta?['full_name'] ?? 'User';
  }

  String get _userEmail => _supabase.auth.currentUser?.email ?? '';

  bool get _isAdmin {
    final email = _supabase.auth.currentUser?.email ?? '';
    return email.toLowerCase() == AdminConstants.adminEmail.toLowerCase();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _logout() async {
    await NotificationStore.instance.reset();
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero / header
              HomeHeroSection(
                userName:     _userName,
                greeting:     _greeting(),
                onProfileTap: _showProfileMenu,
              ),

              // 2. Admin quick-access banner (admin only)
              if (_isAdmin) const HomeAdminBanner(),

              // 3. Why Tokilo feature pills
              const HomeFeaturesSection(),

              // 4. Services
              const HomeServicesSection(),

              // 5. IT Products
              const HomeProductsSection(),

              // 6. Project Showcase + Your Projects (combined)
              const HomeShowcaseSection(),

              // 7. Promos
              const HomePromosSection(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile bottom sheet ──────────────────────────────────────────────────────

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(_userName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary)),
            Text(_userEmail,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            const Divider(),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF03404E)),
                title: const Text('Admin Panel',
                    style: TextStyle(
                        color: Color(0xFF03404E),
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/admin/dashboard');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded,
                  color: AppColors.primary),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Sign Out',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}