// lib/admin/screens/admin_settings_screen.dart
// UPDATED: Replaced Services with My Projects + Client Requests

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_shell.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user  = Supabase.instance.client.auth.currentUser;
    final meta  = user?.userMetadata;
    final name  = meta?['full_name'] ?? 'Admin';
    final email = user?.email ?? '';

    return AdminShell(
      currentPath: '/admin/settings',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AdminAppBar(title: 'Settings', currentPath: '/admin/settings'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProfileCard(name, email),
            const SizedBox(height: 24),
            _buildGroup(
              context: context,
              title: 'Admin Panel',
              items: [
                _Item(icon: Icons.dashboard_rounded,        label: 'Dashboard',              color: AppColors.primary,          onTap: () => context.go('/admin/dashboard')),
                _Item(icon: Icons.work_rounded,             label: 'My Projects',            color: AppColors.primary,          onTap: () => context.go('/admin/portfolio')),
                _Item(icon: Icons.folder_special_rounded,   label: 'Client Requests',        color: AppColors.success,          onTap: () => context.go('/admin/projects')),
                _Item(icon: Icons.devices_rounded,          label: 'Manage IT Products',     color: const Color(0xFF8B5CF6),    onTap: () => context.go('/admin/products')),
                _Item(icon: Icons.home_work_rounded,        label: 'Home Screen Components', color: AppColors.accent,           onTap: () => context.go('/admin/home-components')),
                _Item(icon: Icons.people_rounded,           label: 'App Users',              color: AppColors.warning,          onTap: () => context.go('/admin/users')),
              ],
            ),
            const SizedBox(height: 16),
            _buildGroup(
              context: context,
              title: 'App Navigation',
              items: [
                _Item(icon: Icons.home_rounded,       label: 'Go to App Home',    color: AppColors.warning, onTap: () => context.go('/home')),
                _Item(icon: Icons.storefront_rounded, label: 'Go to Marketplace', color: AppColors.accent,  onTap: () => context.go('/marketplace')),
              ],
            ),
            const SizedBox(height: 16),
            _buildGroup(
              context: context,
              title: 'Account',
              items: [
                _Item(
                  icon: Icons.logout_rounded, label: 'Sign Out', color: AppColors.error, isDestructive: true,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset('assets/icons/tokilologo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  const Text('Tokilo Business Hub', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Admin Panel  v1.0.0', style: TextStyle(fontSize: 11, color: AppColors.textHint, letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(email, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withOpacity(0.4))),
                  child: const Text('Administrator', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup({required BuildContext context, required String title, required List<_Item> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key; final item = entry.value;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(idx == 0 ? 16 : 0), bottom: Radius.circular(idx == items.length - 1 ? 16 : 0)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(width: 38, height: 38, decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Icon(item.icon, color: item.color, size: 20)),
                            const SizedBox(width: 14),
                            Expanded(child: Text(item.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: item.isDestructive ? AppColors.error : AppColors.textPrimary))),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: item.isDestructive ? AppColors.error.withOpacity(0.4) : AppColors.textHint),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (idx < items.length - 1) const Divider(height: 1, indent: 68),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Item {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap; final bool isDestructive;
  const _Item({required this.icon, required this.label, required this.color, required this.onTap, this.isDestructive = false});
}