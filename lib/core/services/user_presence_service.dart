// lib/core/services/user_presence_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/constants/admin_constants.dart';

class UserPresenceService {
  UserPresenceService._();

  static final UserPresenceService instance = UserPresenceService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;

  Future<void> start() async {
    if (_supabase.auth.currentUser == null || _heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => setOnline(),
    );
    await setOnline();
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await setOffline();
  }

  Future<void> setOnline() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final meta = user.userMetadata;
    final email = user.email ?? '';
    final displayName = meta?['full_name']?.toString() ?? email;
    final role = email.toLowerCase() == AdminConstants.adminEmail.toLowerCase()
        ? 'admin'
        : 'client';

    await _updateStatus({
      'user_id': user.id,
      'display_name': displayName,
      'email': email,
      'role': role,
      'is_online': true,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setOffline() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _updateStatus({
      'user_id': user.id,
      'email': user.email,
      'is_online': false,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _updateStatus(Map<String, dynamic> values) async {
    try {
      await _supabase
          .from('user_status')
          .upsert(values)
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      // Presence is best-effort; the next heartbeat retries when online.
      debugPrint('Presence update unavailable: $error');
    }
  }
}
