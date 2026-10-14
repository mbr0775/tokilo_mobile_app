// lib/features/auth/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/tech_scene.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _goToLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _goToSignup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (context.mounted) {
      context.go('/signup');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/icons/tokilologo.png',
                  width: 38,
                  height: 38,
                ),
                const SizedBox(width: 10),
                const Text(
                  'TOKILO',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _goToLogin(context),
                  child: const Text('Sign in'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE7F2F1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const TechScene(height: 275),
            ),
            const SizedBox(height: 30),
            const Text(
              'YOUR DIGITAL PARTNER',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Big ideas.\nBetter beginnings.',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 38),
            ),
            const SizedBox(height: 14),
            const Text(
              'Build your next product, follow your projects and stay connected with the Tokilo team.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _goToSignup(context),
                label: const Text('Get started'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => _goToLogin(context),
                child: const Text('Already have an account? Sign in'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
