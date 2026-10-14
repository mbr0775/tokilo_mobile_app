import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  static const redirectUrl =
      'com.tokilotechnologies.businesshub://login-callback';

  static Future<bool> signIn() {
    return Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : redirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  static String errorMessage(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (error.code == 'access_denied' || message.contains('access_denied')) {
        return 'Google sign-in was cancelled. You can try again.';
      }
      if (message.contains('not enabled') ||
          message.contains('unsupported provider') ||
          error.code == 'provider_disabled') {
        return 'Google sign-in is not available yet. Please use email for now.';
      }
      if (error.code == 'invalid_grant' || error.code == 'flow_state_expired') {
        return 'Google sign-in expired. Please try again.';
      }
    }
    return 'Could not sign in with Google. Check your connection and try again.';
  }
}
