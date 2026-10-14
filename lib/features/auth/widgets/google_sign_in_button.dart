import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/google_auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    this.enabled = true,
    this.canContinue,
    this.onBusyChanged,
    this.signIn = GoogleAuthService.signIn,
  });

  final bool enabled;
  final bool Function()? canContinue;
  final ValueChanged<bool>? onBusyChanged;
  final Future<bool> Function() signIn;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // The browser opens before sign-in completes. Supabase receives the
    // callback and the router handles the resulting session separately.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {},
      onError: (Object error) {
        if (mounted) _showError(GoogleAuthService.errorMessage(error));
      },
    );
  }

  Future<void> _signIn() async {
    if (_isLoading || !widget.enabled) return;
    if (!(widget.canContinue?.call() ?? true)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    widget.onBusyChanged?.call(true);

    try {
      final launched = await widget.signIn();
      if (!launched && mounted) {
        _showError('Could not open Google sign-in. Please try again.');
      }
    } catch (error) {
      if (mounted) _showError(GoogleAuthService.errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.enabled && !_isLoading ? _signIn : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFF747775)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : SvgPicture.asset(
                'assets/icons/google_logo.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
        label: Text(_isLoading ? 'Opening Google...' : 'Continue with Google'),
      ),
    );
  }
}

class AuthMethodDivider extends StatelessWidget {
  const AuthMethodDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}
