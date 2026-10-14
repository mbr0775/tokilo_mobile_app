import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _client
        .channel('mobile_notification_inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _reload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_reads',
          callback: (_) => _reload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'project_notifications',
          callback: (_) => _reload(),
        )
        .subscribe();
  }

  void _reload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Sign in to see your updates.';
        });
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        _client.rpc('tokilo_notification_feed', params: {'p_limit': 100}),
        _client
            .from('project_notifications')
            .select()
            .eq('recipient_id', user.id)
            .order('created_at', ascending: false)
            .limit(100),
      ]).timeout(const Duration(seconds: 15));
      final items = [
        for (final item in results[0] as List)
          {...Map<String, dynamic>.from(item), '_source': 'account'},
        for (final item in results[1] as List)
          {...Map<String, dynamic>.from(item), '_source': 'project'},
      ];
      items.sort(
        (a, b) => (b['created_at']?.toString() ?? '').compareTo(
          a['created_at']?.toString() ?? '',
        ),
      );
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Updates could not load. Please try again.';
        });
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    if (item['is_read'] == true || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (item['_source'] == 'account') {
        await _client.rpc(
          'tokilo_read_notifications',
          params: {'p_notification_id': id},
        );
      } else {
        await _client
            .from('project_notifications')
            .update({'is_read': true})
            .eq('id', id)
            .eq('recipient_id', _client.auth.currentUser!.id);
      }
      if (mounted) setState(() => item['is_read'] = true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark this update as read. Try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your updates'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh updates',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Project progress and account announcements.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_error != null)
            Column(
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            )
          else if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'All caught up',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your new updates will appear here.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: item['is_read'] == true
                      ? Colors.white
                      : const Color(0xFFE7F2F1),
                  borderRadius: BorderRadius.circular(22),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(
                      item['_source'] == 'project'
                          ? Icons.assignment_outlined
                          : Icons.notifications_none_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      item['title']?.toString() ?? 'Project update',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      (item['body'] ?? item['message'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: _busy.contains(item['id'].toString())
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : item['is_read'] == true
                        ? const Icon(
                            Icons.done_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          )
                        : const Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.primary,
                          ),
                    onTap: () => _read(item),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
