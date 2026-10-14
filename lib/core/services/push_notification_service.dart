import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;
  Future<void>? _registration;
  bool _initialized = false;
  String? _pendingConversation, _pendingRecipient;
  void Function(String conversationId)? onConversationOpen;
  StreamSubscription<RemoteMessage>? _messages, _opens;
  StreamSubscription<String>? _tokens;
  static const _channel = AndroidNotificationChannel(
    'tokilo_chat_channel',
    'Tokilo Chat Notifications',
    description: 'Notifications for Tokilo support messages',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_tokilo'),
      ),
      onDidReceiveNotificationResponse: (response) {
        try {
          _open(
            Map<String, dynamic>.from(jsonDecode(response.payload ?? '{}')),
          );
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _messages = FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null ||
          message.data['recipient_id'] != _supabase.auth.currentUser?.id)
        return;
      await _local.show(
        id: notification.hashCode,
        title: notification.title ?? 'Tokilo',
        body: notification.body ?? '',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            icon: '@drawable/ic_stat_tokilo',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });
    _opens = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _open(message.data),
    );
    _tokens = _messaging.onTokenRefresh.listen((token) async {
      try {
        await saveToken(token);
      } catch (_) {
        /* registration retries on next resume */
      }
    });
    _initialized = true;
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _open(initial.data);
    await registerToken();
  }

  void _open(Map<String, dynamic> data) {
    final conversation = data['conversation_id']?.toString();
    final recipient = data['recipient_id']?.toString();
    if (conversation == null ||
        recipient == null ||
        !_uuid(conversation) ||
        !_uuid(recipient))
      return;
    final current = _supabase.auth.currentUser?.id;
    if (current == null) {
      _pendingConversation = conversation;
      _pendingRecipient = recipient;
      return;
    }
    if (current == recipient) onConversationOpen?.call(conversation);
  }

  bool _uuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
  void openPendingConversation() {
    final id = _pendingConversation, recipient = _pendingRecipient;
    _pendingConversation = null;
    _pendingRecipient = null;
    if (id != null && recipient != null)
      _open({'conversation_id': id, 'recipient_id': recipient});
  }

  Future<void> registerToken() =>
      _registration ??= _register().whenComplete(() => _registration = null);
  Future<void> _register() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || kIsWeb || !_initialized) return;
    try {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional)
        return;
      await _messaging.setAutoInitEnabled(true);
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
      );
      if (token == null ||
          token.isEmpty ||
          _supabase.auth.currentUser?.id != userId)
        return;
      await saveToken(token);
    } catch (_) {
      /* Optional notifications never block account access. */
    }
  }

  Future<void> saveToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null || kIsWeb) return;
    await _supabase
        .from('user_push_tokens')
        .upsert({
          'user_id': user.id,
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,token')
        .timeout(const Duration(seconds: 10));
  }

  Future<void> unregisterToken() async {
    _pendingConversation = null;
    _pendingRecipient = null;
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
      );
      final uid = _supabase.auth.currentUser?.id;
      if (token != null && uid != null) {
        await _supabase
            .from('user_push_tokens')
            .delete()
            .eq('user_id', uid)
            .eq('token', token)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      /* Token invalidation below protects a signed-out device even offline. */
    }
    try {
      await _messaging.setAutoInitEnabled(false);
      await _messaging.deleteToken();
    } catch (_) {}
    try {
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _messages?.cancel();
    await _opens?.cancel();
    await _tokens?.cancel();
    _messages = null;
    _opens = null;
    _tokens = null;
    _initialized = false;
    onConversationOpen = null;
  }
}
