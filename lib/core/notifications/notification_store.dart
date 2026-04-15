// lib/core/notifications/notification_store.dart
//
// Real Supabase-backed notification store.
// Fetches notifications for current user + broadcasts (user_id IS NULL).
// Subscribes to realtime so new rows appear instantly.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum NotifType { project, product, portfolio, system, promo, alert }

class AppNotification {
  final String    id;
  final String    title;
  final String    body;
  final NotifType type;
  final String?   refId;
  final String?   refTable;
  final DateTime  createdAt;
  bool            isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    this.refTable,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id:        m['id']        as String,
      title:     m['title']     as String,
      body:      m['body']      as String,
      type:      _parseType(m['type'] as String? ?? 'system'),
      refId:     m['ref_id']    as String?,
      refTable:  m['ref_table'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      isRead:    m['is_read']   as bool? ?? false,
    );
  }

  static NotifType _parseType(String t) {
    switch (t) {
      case 'project':   return NotifType.project;
      case 'product':   return NotifType.product;
      case 'portfolio': return NotifType.portfolio;
      case 'promo':     return NotifType.promo;
      case 'alert':     return NotifType.alert;
      default:          return NotifType.system;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORE
// ─────────────────────────────────────────────────────────────────────────────
class NotificationStore extends ChangeNotifier {
  static final NotificationStore instance = NotificationStore._();
  NotificationStore._();

  final _supabase = Supabase.instance.client;

  final List<AppNotification> _items = [];
  RealtimeChannel? _channel;
  bool _initialized = false;
  bool _isLoading   = false;

  List<AppNotification> get all         => List.unmodifiable(_items);
  int                   get unreadCount => _items.where((n) => !n.isRead).length;
  bool                  get isLoading   => _isLoading;

  // ── Init: called once from HomeScreen ───────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _fetch();
    _subscribe();
  }

  // ── Fetch latest 50 notifications for current user ───────────────────────
  Future<void> _fetch() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // RLS policy on the table returns:
      //   rows where user_id = auth.uid()   (personal notifications)
      //   rows where user_id IS NULL        (broadcast to all users)
      final data = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      _items
        ..clear()
        ..addAll((data as List).map((e) => AppNotification.fromMap(e)));
    } catch (e) {
      debugPrint('NotificationStore._fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Realtime: insert listener ────────────────────────────────────────────
  void _subscribe() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _supabase
        .channel('notifications_channel_$userId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'notifications',
          callback: (payload) {
            final row       = payload.newRecord;
            final rowUserId = row['user_id'] as String?;
            // Accept if broadcast (null) or targeted at this user
            if (rowUserId == null || rowUserId == userId) {
              _items.insert(0, AppNotification.fromMap(row));
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  // ── Public actions ───────────────────────────────────────────────────────

  Future<void> refresh() => _fetch();

  Future<void> markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1 || _items[idx].isRead) return;
    _items[idx].isRead = true;
    notifyListeners();
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      debugPrint('markRead error: $e');
    }
  }

  Future<void> markAllRead() async {
    final unreadIds =
        _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    for (final n in _items) { n.isRead = true; }
    notifyListeners();
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', unreadIds);
    } catch (e) {
      debugPrint('markAllRead error: $e');
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint('remove error: $e');
    }
  }

  Future<void> clearAll() async {
    final ids = _items.map((n) => n.id).toList();
    _items.clear();
    notifyListeners();
    if (ids.isEmpty) return;
    try {
      await _supabase
          .from('notifications')
          .delete()
          .inFilter('id', ids);
    } catch (e) {
      debugPrint('clearAll error: $e');
    }
  }

  // ── Reset on logout ──────────────────────────────────────────────────────
  Future<void> reset() async {
    await _channel?.unsubscribe();
    _channel     = null;
    _initialized = false;
    _items.clear();
    notifyListeners();
  }
}