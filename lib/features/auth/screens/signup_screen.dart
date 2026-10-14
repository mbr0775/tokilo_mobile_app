import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_callback_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/signup_intro.dart';
import '../widgets/signup_consent.dart';
import '../widgets/google_sign_in_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  Future<void> _openLegal(String path) async {
    try {
      final opened = await launchUrl(
        Uri.https('www.tokilotech.com', path),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted)
        _showError('Could not open the policy. Please try again.');
    } catch (_) {
      if (mounted) _showError('Could not open the policy. Please try again.');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showError('Please accept the Terms & Conditions to continue.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: AuthCallbackUrls.signup,
        data: {
          'full_name': _nameController.text.trim(),
          'company_name': _companyController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );
      if (response.session != null) {
        await clearCompletionSession(Supabase.instance.client.auth);
      }
      if (mounted) {
        context.go('/login');
        _showSuccess('Confirm your email, then sign in to continue.');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.outlined(
                          tooltip: 'Back to login',
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'tokilo.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SignupIntro(scrollController: _scrollController),
                    const SizedBox(height: 22),
                    SignupConsent(
                      accepted: _acceptTerms,
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() => _acceptTerms = value),
                      onOpenTerms: () => _openLegal('/terms-and-conditions'),
                      onOpenPrivacy: () => _openLegal('/privacy-policy'),
                    ),
                    const SizedBox(height: 18),
                    GoogleSignInButton(
                      enabled: !_isLoading,
                      canContinue: () {
                        if (_acceptTerms) return true;
                        _showError(
                          'Please accept the Terms & Conditions to continue.',
                        );
                        return false;
                      },
                      onBusyChanged: (busy) =>
                          setState(() => _isLoading = busy),
                    ),
                    const AuthMethodDivider(
                      label: 'or create an account with email',
                    ),
                    // Full Name
                    AuthTextField(
                      controller: _nameController,
                      label: AppStrings.fullName,
                      hint: 'Enter your full name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return AppStrings.nameRequired;
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Company Name
                    AuthTextField(
                      controller: _companyController,
                      label: AppStrings.companyName,
                      hint: 'Enter your company name (optional)',
                      prefixIcon: Icons.business_outlined,
                    ),

                    const SizedBox(height: 14),

                    // Email
                    AuthTextField(
                      controller: _emailController,
                      label: AppStrings.email,
                      hint: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return AppStrings.emailRequired;
                        if (!RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(val)) {
                          return AppStrings.invalidEmail;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Phone Number
                    AuthTextField(
                      controller: _phoneController,
                      label: AppStrings.phoneNumber,
                      hint: 'Phone number (optional)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),

                    const SizedBox(height: 14),

                    // Password
                    AuthTextField(
                      controller: _passwordController,
                      label: AppStrings.password,
                      hint: 'Create a strong password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return AppStrings.passwordRequired;
                        if (val.length < 6) return AppStrings.passwordTooShort;
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Confirm Password
                    AuthTextField(
                      controller: _confirmPasswordController,
                      label: AppStrings.confirmPassword,
                      hint: 'Re-enter your password',
                      obscureText: _obscureConfirm,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Please confirm your password';
                        if (val != _passwordController.text)
                          return AppStrings.passwordsNotMatch;
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    GradientButton(
                      label: 'Create Account',
                      isLoading: _isLoading,
                      onPressed: _signup,
                    ),

                    const SizedBox(height: 24),

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          AppStrings.alreadyHaveAccount,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text(AppStrings.loginNow),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
