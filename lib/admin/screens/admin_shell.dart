// lib/admin/screens/admin_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

// ── Global scaffold key shared between AdminShell and AdminAppBar ─────────────
// This is the ONLY reliable way to open a drawer from an AppBar that lives
// inside a nested Scaffold.
final GlobalKey<ScaffoldState> adminScaffoldKey = GlobalKey<ScaffoldState>();

class AdminShell extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const AdminShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  bool get _isDashboard => currentPath == '/admin/dashboard';

  String get _userName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['full_name'] ?? 'Admin';
  }

  String get _userEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // The OUTER Scaffold owns the drawer and uses adminScaffoldKey
    return Scaffold(
      key: adminScaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      body: child, // child is another Scaffold (the actual screen)
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF03404E),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildDrawerTile(
                      icon: Icons.home_rounded,
                      label: 'Go to Home',
                      color: AppColors.accent,
                      onTap: () {
                        adminScaffoldKey.currentState?.closeDrawer();
                        context.go('/home');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDrawerTile(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      color: AppColors.error,
                      onTap: () {
                        adminScaffoldKey.currentState?.closeDrawer();
                        _logout(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Tokilo Admin  •  v1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/icons/tokilologo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOKILO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Admin AppBar ───────────────────────────────────────────────────────
//
// Uses adminScaffoldKey.currentState?.openDrawer() directly —
// this always works regardless of nesting depth.
//
// Rules:
//   • /admin/dashboard → hamburger ONLY on left
//   • all other screens → back arrow on left + hamburger on right
//
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final String? currentPath;

  const AdminAppBar({
    super.key,
    required this.title,
    this.actions,
    this.currentPath,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  bool get _isDashboard =>
      currentPath == null || currentPath == '/admin/dashboard';

  void _openDrawer() => adminScaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF03404E),
      elevation: 0,
      automaticallyImplyLeading: false,

      // ── Leading ────────────────────────────────────────────────────────────
      leading: _isDashboard
          // Dashboard → hamburger on left
          ? IconButton(
              icon: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 26),
              onPressed: _openDrawer,
            )
          // Other screens → back arrow on left
          : IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/admin/dashboard');
                }
              },
            ),

      // ── Title ──────────────────────────────────────────────────────────────
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),

      // ── Actions ────────────────────────────────────────────────────────────
      // Non-dashboard: hamburger on right side too
      actions: [
        if (!_isDashboard)
          IconButton(
            icon: const Icon(Icons.menu_rounded,
                color: Colors.white, size: 26),
            onPressed: _openDrawer,
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}