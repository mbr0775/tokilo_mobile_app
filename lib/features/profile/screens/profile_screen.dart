// lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../admin/navigation/admin_router.dart';
import 'about_tokilo_screen.dart';
import '../../../core/widgets/tokilo_motion.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/user_presence_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _openPolicy(String path) async {
    final opened = await launchUrl(
      Uri.https('www.tokilotech.com', path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this page. Please visit www.tokilotech.com.',
          ),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('seen_onboarding');

      await UserPresenceService.instance.stop();
      if (Firebase.apps.isNotEmpty)
        await PushNotificationService.instance.unregisterToken();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);

      if (context.mounted) {
        context.go('/splash');
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    if (_busy) return;
    if (isAdminUser()) {
      await _openPolicy('/delete-account');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),

          content: const Text(
            'Are you sure you want to permanently delete your Tokilo account? This action cannot be undone.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },

              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await AccountService(Supabase.instance.client).deleteCurrentAccount(
        clearDeviceRegistration: () async {
          if (Firebase.apps.isNotEmpty)
            await PushNotificationService.instance.unregisterToken();
        },
      );

      if (context.mounted &&
          Supabase.instance.client.auth.currentSession == null) {
        context.go('/splash');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name']?.toString() ?? 'Your account';
    final email = user?.email ?? '';
    final company =
        user?.userMetadata?['company_name']?.toString() ?? 'Not set';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your space.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Account, support and everything Tokilo.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ScrollReveal(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2F1),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      child: Text(
                        name.isEmpty
                            ? 'T'
                            : name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
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
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                _Detail(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: name,
                ),
                const Divider(indent: 60),
                _Detail(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email address',
                  value: email,
                ),
                const Divider(indent: 60),
                _Detail(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: company,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Stay connected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/notifications'),
                ),
                const Divider(indent: 60),
                ListTile(
                  leading: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Help & support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push(isAdminUser() ? '/admin/messages' : '/chat'),
                ),
                const Divider(indent: 60),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('About Tokilo'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutTokiloScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPolicy('/privacy-policy'),
                ),
                const Divider(indent: 60),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Terms & conditions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPolicy('/terms-and-conditions'),
                ),
                const Divider(indent: 60),
                ListTile(
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Account deletion help'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPolicy('/delete-account'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign out'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : () => _deleteAccount(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              label: Text(_busy ? 'Please wait…' : 'Delete account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(children: children),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primary, size: 22),
    title: Text(
      label,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
