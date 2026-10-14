import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackUrls {
  static const mobileSignup =
      'com.tokilotechnologies.businesshub://email-confirmed';
  static String get signup =>
      kIsWeb ? '${Uri.base.origin}/login?auth_flow=signup' : mobileSignup;
}

/// Own callback dispatch so email confirmation never becomes automatic login.
/// Supabase still validates/exchanges Google and recovery codes using PKCE.
class AuthCallbackService {
  AuthCallbackService({
    required this.auth,
    required this.onEmailConfirmation,
    required this.onError,
  });
  final GoTrueClient auth;
  final Future<void> Function() onEmailConfirmation;
  final void Function(Object) onError;
  StreamSubscription<Uri>? _subscription;
  Future<void> _queue = Future<void>.value();
  String? _lastUri;
  bool _disposed = false;

  void start({Stream<Uri>? links}) {
    if (kIsWeb && links == null) {
      unawaited(handle(Uri.base));
    } else {
      _subscription = (links ?? AppLinks().uriLinkStream).listen(
        (uri) => unawaited(handle(uri)),
        onError: onError,
      );
    }
  }

  Future<void> handle(Uri uri) {
    final accepted = kIsWeb
        ? uri.origin == Uri.base.origin
        : uri.scheme == 'com.tokilotechnologies.businesshub' &&
              (uri.host == 'login-callback' || uri.host == 'email-confirmed');
    if (!accepted || _disposed) return Future<void>.value();
    final encoded = uri.toString();
    if (_lastUri == encoded) return _queue;
    _lastUri = encoded;
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        final params = {
          ...uri.queryParameters,
          if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
        };
        final confirmation =
            uri.host == 'email-confirmed' || params['auth_flow'] == 'signup';
        if (confirmation) {
          // The email verification endpoint has already processed the link.
          // Do not redeem its code for an app session. Require explicit login.
          await onEmailConfirmation();
          if (params.containsKey('error_description') ||
              params.containsKey('error')) {
            throw const AuthException('Email confirmation link unavailable.');
          }
        } else if (params.containsKey('code') ||
            params.containsKey('access_token') ||
            params.containsKey('error_description')) {
          await auth.getSessionFromUrl(uri);
        }
      } catch (error) {
        if (!_disposed) onError(error);
      }
    });
    return _queue;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _lastUri = null;
  }
}

/// Local logout runs before the network revoke request in the Supabase SDK.
/// A failed network revoke must not keep a cleared session on a private screen.
Future<void> clearCompletionSession(GoTrueClient auth) async {
  try {
    await auth
        .signOut(scope: SignOutScope.local)
        .timeout(const Duration(seconds: 12));
  } catch (_) {
    if (auth.currentSession != null) rethrow;
  }
  if (auth.currentSession != null) {
    throw StateError('Temporary auth session could not be cleared.');
  }
}
