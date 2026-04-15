import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    final name = meta?['full_name'] ?? 'User';
    final email = user?.email ?? '';
    final company = meta?['company_name'] ?? 'Not set';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Edit', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar & info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Free Plan',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Info cards
          _buildInfoSection(
            title: 'Account Details',
            items: [
              {'icon': Icons.person_outline_rounded, 'label': 'Full Name', 'value': name},
              {'icon': Icons.email_outlined, 'label': 'Email', 'value': email},
              {'icon': Icons.business_outlined, 'label': 'Company', 'value': company},
            ],
          ),

          const SizedBox(height: 20),

          _buildSettingsSection(context),

          const SizedBox(height: 20),

          // Logout button
          OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required List<Map<String, dynamic>> items}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1),
          ...items.map((item) => ListTile(
                leading: Icon(item['icon'] as IconData, color: AppColors.primary, size: 22),
                title: Text(item['label'] as String,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                subtitle: Text(item['value'] as String,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                dense: true,
              )),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final items = [
      {'icon': Icons.notifications_outlined, 'label': 'Notifications'},
      {'icon': Icons.security_outlined, 'label': 'Security & Password'},
      {'icon': Icons.workspace_premium_outlined, 'label': 'Subscription & Billing'},
      {'icon': Icons.help_outline_rounded, 'label': 'Help & Support'},
      {'icon': Icons.info_outline_rounded, 'label': 'About Tokilo'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1),
          ...items.map((item) => ListTile(
                leading: Icon(item['icon'] as IconData, color: AppColors.textSecondary, size: 22),
                title: Text(item['label'] as String, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
                onTap: () {},
                dense: true,
              )),
        ],
      ),
    );
  }
}