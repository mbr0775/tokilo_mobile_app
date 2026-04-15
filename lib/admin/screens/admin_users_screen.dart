// lib/admin/screens/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_shell.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _users     = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/users',
      child: Scaffold(
        backgroundColor: AppColors.background,
        // ✅ currentPath passed → shows back arrow on left, hamburger on right
        appBar: AdminAppBar(
          title: 'App Users (${_users.length})',
          currentPath: '/admin/users',
          actions: [
            IconButton(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _users.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (_, i) => _buildUserCard(_users[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 72, color: AppColors.success.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No Users Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Users who sign up will appear here.\nEnsure a "profiles" table exists in Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      );

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name    = user['full_name']    ?? 'Unknown';
    final email   = user['email']        ?? '';
    final company = user['company_name'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(initial,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                if (company.isNotEmpty)
                  Text(company,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}