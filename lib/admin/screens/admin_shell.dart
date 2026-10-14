// lib/admin/screens/admin_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AdminShell({super.key, required this.child, required this.currentPath});

  static void openDrawer(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_AdminShellScope>();
    final scope = element?.widget as _AdminShellScope?;
    scope?.openDrawer();
  }

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _userName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['full_name'] ?? 'Admin';
  }

  String get _userEmail {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seen_onboarding');

    await Supabase.instance.client.auth.signOut();

    if (context.mounted) {
      context.go('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminShellScope(
      openDrawer: _openDrawer,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: _buildDrawer(context),
        body: widget.child,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) => Drawer(
    backgroundColor: Colors.white,
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Image.asset('assets/icons/tokilologo.png', width: 40, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'YOUR WORKSPACE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in const [
            (Icons.dashboard_outlined, 'Dashboard', '/admin/dashboard'),
            (Icons.home_outlined, 'Client home', '/home'),
            (Icons.work_outline_rounded, 'My projects', '/admin/portfolio'),
            (Icons.assignment_outlined, 'Client requests', '/admin/projects'),
            (Icons.chat_bubble_outline_rounded, 'Messages', '/admin/messages'),
            (Icons.photo_library_outlined, 'Showcase', '/admin/showcase'),
            (Icons.payments_outlined, 'Service pricing', '/admin/pricing'),
            (Icons.settings_outlined, 'Settings', '/admin/settings'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                selected: widget.currentPath == item.$3,
                selectedTileColor: const Color(0xFFE7F2F1),
                selectedColor: AppColors.primary,
                leading: Icon(item.$1, size: 22),
                title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  _closeDrawer();
                  context.go(item.$3);
                },
              ),
            ),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Sign out'),
            onTap: () {
              _closeDrawer();
              _logout(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _AdminShellScope extends InheritedWidget {
  final VoidCallback openDrawer;

  const _AdminShellScope({required this.openDrawer, required super.child});

  @override
  bool updateShouldNotify(_AdminShellScope oldWidget) {
    return false;
  }
}

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

  bool get _isDashboard {
    return currentPath == null || currentPath == '/admin/dashboard';
  }

  void _openDrawer(BuildContext context) {
    AdminShell.openDrawer(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: _isDashboard
          ? IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: AppColors.textPrimary,
                size: 26,
              ),
              tooltip: 'Open workspace menu',
              onPressed: () => _openDrawer(context),
            )
          : IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/admin/dashboard');
                }
              },
            ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        if (!_isDashboard)
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 26,
            ),
            tooltip: 'Open workspace menu',
            onPressed: () => _openDrawer(context),
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}
