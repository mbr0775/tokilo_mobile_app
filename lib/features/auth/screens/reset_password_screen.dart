import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../navigation/app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.onUpdated});
  final VoidCallback? onUpdated;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        throw StateError('Recovery session expired');
      }
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _password.text))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      final messenger = ScaffoldMessenger.of(context);
      (widget.onUpdated ?? AppRouter.completePasswordRecovery)();
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your password has been updated.')),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update your password. Please request a new reset link and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Set a new password'),
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Choose a password you haven’t used before.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) => value != _password.text
                      ? 'The passwords don’t match.'
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Updating…' : 'Update password'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
