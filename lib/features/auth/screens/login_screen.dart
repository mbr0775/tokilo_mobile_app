// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../admin/constants/admin_constants.dart';  // ← admin email check
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/auth_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _emailController  = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _rememberMe      = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // ✅ Admin email → Admin Panel, everyone else → Home
        final email = _emailController.text.trim().toLowerCase();
        if (email == AdminConstants.adminEmail.toLowerCase()) {
          context.go('/admin/dashboard');
        } else {
          context.go('/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                const AuthHeader(
                  title:    'Welcome Back!',
                  subtitle: 'Sign in to your Tokilo Business Hub',
                ),

                const SizedBox(height: 40),

                // Email
                AuthTextField(
                  controller:   _emailController,
                  label:        AppStrings.email,
                  hint:         'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon:   Icons.email_outlined,
                  validator: (val) {
                    if (val == null || val.isEmpty) return AppStrings.emailRequired;
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(val))
                      return AppStrings.invalidEmail;
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                AuthTextField(
                  controller:   _passwordController,
                  label:        AppStrings.password,
                  hint:         'Enter your password',
                  obscureText:  _obscurePassword,
                  prefixIcon:   Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return AppStrings.passwordRequired;
                    if (val.length < 6) return AppStrings.passwordTooShort;
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Remember me + Forgot password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20, height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(AppStrings.rememberMe,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot Password?',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                GradientButton(
                  label:     AppStrings.login,
                  isLoading: _isLoading,
                  onPressed: _login,
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(AppStrings.dontHaveAccount,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: const Text(AppStrings.signUpNow,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}