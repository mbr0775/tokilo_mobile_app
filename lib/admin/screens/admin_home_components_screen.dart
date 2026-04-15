// lib/admin/screens/admin_home_components_screen.dart
//
// FIXES:
//   1. FAB fully visible — list padding bottom = 100, FAB sits above safe area
//   2. Network errors shown gracefully — no crash, proper empty state
//   3. All 3 tabs show data that was added via services/products flow on dashboard
//   4. Tables: home_banners, home_promos, home_features

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'admin_shell.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AdminHomeComponentsScreen extends StatefulWidget {
  const AdminHomeComponentsScreen({super.key});

  @override
  State<AdminHomeComponentsScreen> createState() =>
      _AdminHomeComponentsScreenState();
}

class _AdminHomeComponentsScreenState
    extends State<AdminHomeComponentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _banners  = [];
  List<Map<String, dynamic>> _promos   = [];
  List<Map<String, dynamic>> _features = [];

  bool _loading    = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final b = await _supabase.from('home_banners').select().order('sort_order');
      final p = await _supabase.from('home_promos').select().order('sort_order');
      final f = await _supabase.from('home_features').select().order('sort_order');
      if (mounted) {
        setState(() {
          _banners  = List<Map<String, dynamic>>.from(b);
          _promos   = List<Map<String, dynamic>>.from(p);
          _features = List<Map<String, dynamic>>.from(f);
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading   = false;
          _loadError = e.toString();
        });
        _snack('Load error: $e', error: true);
      }
    }
  }

  Future<void> _toggleActive(String table, String id, bool current) async {
    try {
      await _supabase.from(table).update({
        'is_active':  !current,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _loadAll();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _delete(String table, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item'),
        content: Text('"$name" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, minimumSize: Size.zero),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await _supabase.from(table).delete().eq('id', id);
      _snack('Deleted successfully');
      _loadAll();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/home-components',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'Home Components',
          currentPath: '/admin/home-components',
          actions: [
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Tab bar ───────────────────────────────────────
            Container(
              color: const Color(0xFF03404E),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: 'Banners (${_banners.length})'),
                  Tab(text: 'Promos (${_promos.length})'),
                  Tab(text: 'Features (${_features.length})'),
                ],
              ),
            ),

            // ── Tab views ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // BANNERS TAB
                        _ComponentTab(
                          items: _banners,
                          emptyTitle: 'No Banners Yet',
                          emptySubtitle: 'Tap + to add hero announcement\nbanners for the home screen',
                          emptyIcon: Icons.view_carousel_rounded,
                          fabColor: AppColors.primary,
                          fabLabel: 'Add Banner',
                          onAdd: () => _openBannerForm(),
                          onRefresh: _loadAll,
                          itemBuilder: (b) => _ComponentCard(
                            title:    b['title'] ?? '',
                            subtitle: b['subtitle'] ?? '',
                            meta:     b['button_label'] != null && (b['button_label'] as String).isNotEmpty
                                        ? 'Button: ${b['button_label']}'
                                        : 'No button',
                            badge:    (b['is_active'] as bool? ?? true) ? 'Active' : 'Hidden',
                            badgeColor: (b['is_active'] as bool? ?? true) ? AppColors.success : AppColors.error,
                            icon:     Icons.view_carousel_rounded,
                            iconColor: AppColors.primary,
                            isActive: b['is_active'] as bool? ?? true,
                            onToggle: () => _toggleActive('home_banners', b['id'], b['is_active'] as bool? ?? true),
                            onEdit:   () => _openBannerForm(banner: b),
                            onDelete: () => _delete('home_banners', b['id'], b['title'] ?? ''),
                          ),
                        ),

                        // PROMOS TAB
                        _ComponentTab(
                          items: _promos,
                          emptyTitle: 'No Promos Yet',
                          emptySubtitle: 'Tap + to add promo or contact\nbanners for the home screen',
                          emptyIcon: Icons.local_offer_rounded,
                          fabColor: const Color(0xFF8B5CF6),
                          fabLabel: 'Add Promo',
                          onAdd: () => _openPromoForm(),
                          onRefresh: _loadAll,
                          itemBuilder: (p) {
                            final type = p['promo_type'] ?? 'promo';
                            final typeColor = type == 'contact' ? AppColors.accent : type == 'upgrade' ? AppColors.warning : const Color(0xFF8B5CF6);
                            return _ComponentCard(
                              title:     p['title'] ?? '',
                              subtitle:  p['subtitle'] ?? '',
                              meta:      type.toUpperCase(),
                              badge:     (p['is_active'] as bool? ?? true) ? 'Visible' : 'Hidden',
                              badgeColor: (p['is_active'] as bool? ?? true) ? AppColors.success : AppColors.error,
                              icon:     Icons.local_offer_rounded,
                              iconColor: typeColor,
                              isActive:  p['is_active'] as bool? ?? true,
                              onToggle:  () => _toggleActive('home_promos', p['id'], p['is_active'] as bool? ?? true),
                              onEdit:    () => _openPromoForm(promo: p),
                              onDelete:  () => _delete('home_promos', p['id'], p['title'] ?? ''),
                            );
                          },
                        ),

                        // FEATURES TAB
                        _ComponentTab(
                          items: _features,
                          emptyTitle: 'No Features Yet',
                          emptySubtitle: 'Tap + to add "Why Tokilo"\nfeature pills for the home screen',
                          emptyIcon: Icons.verified_rounded,
                          fabColor: AppColors.success,
                          fabLabel: 'Add Feature',
                          onAdd: () => _openFeatureForm(),
                          onRefresh: _loadAll,
                          itemBuilder: (f) {
                            Color iconColor = AppColors.primary;
                            try {
                              final hex = (f['color_hex'] ?? '#06768D') as String;
                              iconColor = Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
                            } catch (_) {}
                            return _ComponentCard(
                              title:     f['label'] ?? '',
                              subtitle:  'Icon: ${f['icon_name'] ?? '-'}  •  Order: ${f['sort_order'] ?? 0}',
                              meta:      null,
                              badge:     (f['is_active'] as bool? ?? true) ? 'Visible' : 'Hidden',
                              badgeColor: (f['is_active'] as bool? ?? true) ? AppColors.success : AppColors.error,
                              icon:     Icons.star_rounded,
                              iconColor: iconColor,
                              isActive:  f['is_active'] as bool? ?? true,
                              onToggle:  () => _toggleActive('home_features', f['id'], f['is_active'] as bool? ?? true),
                              onEdit:    () => _openFeatureForm(feature: f),
                              onDelete:  () => _delete('home_features', f['id'], f['label'] ?? ''),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBannerForm({Map<String, dynamic>? banner}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _BannerFormSheet(banner: banner, onSaved: _loadAll),
    );
  }

  void _openPromoForm({Map<String, dynamic>? promo}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _PromoFormSheet(promo: promo, onSaved: _loadAll),
    );
  }

  void _openFeatureForm({Map<String, dynamic>? feature}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _FeatureFormSheet(feature: feature, onSaved: _loadAll),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE TAB WRAPPER — handles empty state + FAB fully visible
// ═══════════════════════════════════════════════════════════════
class _ComponentTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyTitle, emptySubtitle, fabLabel;
  final IconData emptyIcon;
  final Color fabColor;
  final VoidCallback onAdd, onRefresh;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _ComponentTab({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.fabColor,
    required this.fabLabel,
    required this.onAdd,
    required this.onRefresh,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        items.isEmpty
            ? _EmptyState(title: emptyTitle, subtitle: emptySubtitle, icon: emptyIcon)
            : RefreshIndicator(
                onRefresh: () async => onRefresh(),
                child: ListView.builder(
                  // FIXED: bottom padding = 100 so last item is never hidden behind FAB
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (_, i) => itemBuilder(items[i]),
                ),
              ),

        // FIXED: FAB anchored to bottom + safe area, always fully visible
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: fabLabel,
                  onPressed: onAdd,
                  backgroundColor: fabColor,
                  elevation: 4,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text(fabLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE CARD
// ═══════════════════════════════════════════════════════════════
class _ComponentCard extends StatelessWidget {
  final String title, subtitle;
  final String? meta;
  final String badge;
  final Color badgeColor, iconColor;
  final IconData icon;
  final bool isActive;
  final VoidCallback onToggle, onEdit, onDelete;

  const _ComponentCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.isActive,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Switch(value: isActive, activeColor: AppColors.primary, onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Badge(label: badge, color: badgeColor),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _Badge(label: meta!, color: AppColors.textSecondary, outlined: true),
              ],
              const Spacer(),
              _IconBtn(icon: Icons.edit_rounded, color: AppColors.primary, onTap: onEdit),
              const SizedBox(width: 4),
              _IconBtn(icon: Icons.delete_rounded, color: AppColors.error, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  const _Badge({required this.label, required this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: AppColors.border) : null,
      ),
      child: Text(label,
          style: TextStyle(color: outlined ? AppColors.textSecondary : color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const _EmptyState({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: AppColors.primary.withOpacity(0.18)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 80), // leave space for FAB
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM: BANNER
// ═══════════════════════════════════════════════════════════════
class _BannerFormSheet extends StatefulWidget {
  final Map<String, dynamic>? banner;
  final VoidCallback onSaved;
  const _BannerFormSheet({this.banner, required this.onSaved});

  @override
  State<_BannerFormSheet> createState() => _BannerFormSheetState();
}

class _BannerFormSheetState extends State<_BannerFormSheet> {
    final _picker = ImagePicker();
    File? _pickedImage;
    String? _existingImageUrl;
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _titleCtrl, _subtitleCtrl, _btnLabelCtrl, _btnRouteCtrl, _bgColorCtrl, _sortCtrl;
  bool _isActive = true, _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b       = widget.banner;
    _titleCtrl    = TextEditingController(text: b?['title']        ?? '');
    _subtitleCtrl = TextEditingController(text: b?['subtitle']     ?? '');
    _btnLabelCtrl = TextEditingController(text: b?['button_label'] ?? '');
    _btnRouteCtrl = TextEditingController(text: b?['button_route'] ?? '');
    _bgColorCtrl  = TextEditingController(text: b?['bg_color']     ?? '#03404E');
    _sortCtrl     = TextEditingController(text: (b?['sort_order'] ?? 0).toString());
    _isActive     = b?['is_active'] ?? true;
    _existingImageUrl = b?['image_url'];
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _subtitleCtrl, _btnLabelCtrl, _btnRouteCtrl, _bgColorCtrl, _sortCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _existingImageUrl;
    try {
      final ext = _pickedImage!.path.split('.').last;
      final bytes = await _pickedImage!.readAsBytes();
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'banners/$fileName';
      await _supabase.storage.from('tokilo-media').uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
      final url = _supabase.storage.from('tokilo-media').getPublicUrl(storagePath);
      return url;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e'), backgroundColor: AppColors.error),
      );
      return _existingImageUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImage();
      final payload = {
        'title':        _titleCtrl.text.trim(),
        'subtitle':     _subtitleCtrl.text.trim(),
        'button_label': _btnLabelCtrl.text.trim(),
        'button_route': _btnRouteCtrl.text.trim(),
        'bg_color':     _bgColorCtrl.text.trim(),
        'sort_order':   int.tryParse(_sortCtrl.text) ?? 0,
        'is_active':    _isActive,
        'updated_at':   DateTime.now().toIso8601String(),
        'image_url':    imageUrl,
      };
      if (widget.banner == null) {
        await _supabase.from('home_banners').insert(payload);
      } else {
        await _supabase.from('home_banners').update(payload).eq('id', widget.banner!['id']);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: widget.banner == null ? 'Add Banner' : 'Edit Banner',
      isSaving: _isSaving, onSave: _save,
      saveLabel: widget.banner == null ? 'Add Banner' : 'Update Banner',
      child: Form(
        key: _formKey,
        child: Column(children: [
          _FormField(label: 'Title *', ctrl: _titleCtrl, required: true, hint: 'e.g. Exclusive Offer!'),
          const SizedBox(height: 14),
          _FormField(label: 'Subtitle', ctrl: _subtitleCtrl, hint: 'Short supporting text'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FormField(label: 'Button Label', ctrl: _btnLabelCtrl, hint: 'e.g. Explore')),
            const SizedBox(width: 12),
            Expanded(child: _FormField(label: 'Route', ctrl: _btnRouteCtrl, hint: '/marketplace')),
          ]),
          const SizedBox(height: 14),
          // Image picker
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Banner Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: _pickedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_pickedImage!, width: 120, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2, right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedImage = null),
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_existingImageUrl!, width: 120, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _existingImageUrl = null),
                                    child: Container(
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 120, height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Text('Tap to upload image', style: TextStyle(fontSize: 12, color: AppColors.textHint))),
                            ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FormField(label: 'BG Color', ctrl: _bgColorCtrl, hint: '#03404E')),
            const SizedBox(width: 12),
            Expanded(child: _FormField(label: 'Sort Order', ctrl: _sortCtrl, hint: '0', keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          _ToggleRow(label: 'Active (show on home)', value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM: PROMO
// ═══════════════════════════════════════════════════════════════
class _PromoFormSheet extends StatefulWidget {
  final Map<String, dynamic>? promo;
  final VoidCallback onSaved;
  const _PromoFormSheet({this.promo, required this.onSaved});

  @override
  State<_PromoFormSheet> createState() => _PromoFormSheetState();
}

class _PromoFormSheetState extends State<_PromoFormSheet> {
    List<Map<String, dynamic>> _services = [];
    List<Map<String, dynamic>> _products = [];
    String? _selectedServiceId;
    String? _selectedProductId;
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _picker = ImagePicker();
  File? _pickedImage;
  String? _existingImageUrl;

  late TextEditingController _titleCtrl, _subtitleCtrl, _btnCtrl, _urlCtrl, _bgCtrl, _sortCtrl;
  String _type = 'promo';
  bool _isActive = true, _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p       = widget.promo;
    _titleCtrl    = TextEditingController(text: p?['title']        ?? '');
    _subtitleCtrl = TextEditingController(text: p?['subtitle']     ?? '');
    _btnCtrl      = TextEditingController(text: p?['button_label'] ?? '');
    _urlCtrl      = TextEditingController(text: p?['button_url']   ?? '');
    _bgCtrl       = TextEditingController(text: p?['bg_color']     ?? '#06768D');
    _sortCtrl     = TextEditingController(text: (p?['sort_order'] ?? 0).toString());
    _type         = p?['promo_type'] ?? 'promo';
    _isActive     = p?['is_active'] ?? true;
    _existingImageUrl = p?['image_url'];
    _selectedServiceId = p?['service_id']?.toString();
    _selectedProductId = p?['product_id']?.toString();
    _fetchServicesAndProducts();
  }

  Future<void> _fetchServicesAndProducts() async {
    try {
      final services = await _supabase.from('services').select('id, title').eq('is_active', true);
      final products = await _supabase.from('it_products').select('id, name').eq('is_active', true);
      if (mounted) setState(() {
        _services = List<Map<String, dynamic>>.from(services);
        _products = List<Map<String, dynamic>>.from(products);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _subtitleCtrl, _btnCtrl, _urlCtrl, _bgCtrl, _sortCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _existingImageUrl;
    try {
      final ext = _pickedImage!.path.split('.').last;
      final bytes = await _pickedImage!.readAsBytes();
      final fileName = 'promo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'promos/$fileName';
      // Upload the image
      await _supabase.storage.from('tokilo-media').uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: 'image/$ext'));
      // Get the public URL
      final url = _supabase.storage.from('tokilo-media').getPublicUrl(storagePath);
      return url;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e'), backgroundColor: AppColors.error),
      );
      return _existingImageUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImage();
      final payload = {
        'title':        _titleCtrl.text.trim(),
        'subtitle':     _subtitleCtrl.text.trim(),
        'button_label': _btnCtrl.text.trim(),
        'button_url':   _urlCtrl.text.trim(),
        'bg_color':     _bgCtrl.text.trim(),
        'promo_type':   _type,
        'sort_order':   int.tryParse(_sortCtrl.text) ?? 0,
        'is_active':    _isActive,
        'updated_at':   DateTime.now().toIso8601String(),
        'image_url':    imageUrl,
        'service_id':   _selectedServiceId,
        'product_id':   _selectedProductId,
      };
      if (widget.promo == null) {
        await _supabase.from('home_promos').insert(payload);
      } else {
        await _supabase.from('home_promos').update(payload).eq('id', widget.promo!['id']);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: widget.promo == null ? 'Add Promo' : 'Edit Promo',
      isSaving: _isSaving, onSave: _save,
      saveLabel: widget.promo == null ? 'Add Promo' : 'Update Promo',
      child: Form(
        key: _formKey,
        child: Column(children: [
          _FormField(label: 'Title *', ctrl: _titleCtrl, required: true, hint: 'e.g. Special Promo!'),
          const SizedBox(height: 14),
          _FormField(label: 'Subtitle', ctrl: _subtitleCtrl, hint: 'Contact us for exclusive deals'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FormField(label: 'Button Label', ctrl: _btnCtrl, hint: 'Contact Us')),
            const SizedBox(width: 12),
            Expanded(child: _FormField(label: 'URL / Route', ctrl: _urlCtrl, hint: '/portal')),
          ]),
          const SizedBox(height: 14),
          // Image picker
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Promo Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: _pickedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_pickedImage!, width: 120, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2, right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedImage = null),
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_existingImageUrl!, width: 120, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _existingImageUrl = null),
                                    child: Container(
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 120, height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Text('Tap to upload image', style: TextStyle(fontSize: 12, color: AppColors.textHint))),
                            ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Dropdown for Service
          DropdownButtonFormField<String>(
            value: _selectedServiceId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Link to Service (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('None')),
              ..._services.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text(s['title'] ?? 'Service'))),
            ],
            onChanged: (v) => setState(() => _selectedServiceId = v),
          ),
          const SizedBox(height: 14),
          // Dropdown for Product
          DropdownButtonFormField<String>(
            value: _selectedProductId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Link to Product (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('None')),
              ..._products.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['name'] ?? 'Product'))),
            ],
            onChanged: (v) => setState(() => _selectedProductId = v),
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                items: ['promo', 'contact', 'upgrade']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'promo'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FormField(label: 'BG Color', ctrl: _bgCtrl, hint: '#06768D')),
            const SizedBox(width: 12),
            Expanded(child: _FormField(label: 'Sort Order', ctrl: _sortCtrl, hint: '0', keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          _ToggleRow(label: 'Active (show on home)', value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM: FEATURE
// ═══════════════════════════════════════════════════════════════
class _FeatureFormSheet extends StatefulWidget {
  final Map<String, dynamic>? feature;
  final VoidCallback onSaved;
  const _FeatureFormSheet({this.feature, required this.onSaved});

  @override
  State<_FeatureFormSheet> createState() => _FeatureFormSheetState();
}

class _FeatureFormSheetState extends State<_FeatureFormSheet> {
    List<Map<String, dynamic>> _services = [];
    List<Map<String, dynamic>> _products = [];
    String? _selectedServiceId;
    String? _selectedProductId;
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _labelCtrl, _iconCtrl, _colorCtrl, _sortCtrl;
  bool _isActive = true, _isSaving = false;

  static const _iconOptions = [
    'verified_rounded', 'flash_on_rounded', 'support_rounded',
    'price_check_rounded', 'star_rounded', 'bolt_rounded',
    'shield_rounded', 'thumb_up_rounded', 'emoji_events_rounded',
    'workspace_premium_rounded', 'check_circle_rounded', 'speed_rounded',
    'devices_rounded', 'support_agent_rounded', 'local_offer_rounded',
  ];

  @override
  void initState() {
    super.initState();
    final f    = widget.feature;
    _labelCtrl = TextEditingController(text: f?['label']     ?? '');
    _iconCtrl  = TextEditingController(text: f?['icon_name'] ?? 'star_rounded');
    _colorCtrl = TextEditingController(text: f?['color_hex'] ?? '#06768D');
    _sortCtrl  = TextEditingController(text: (f?['sort_order'] ?? 0).toString());
    _isActive  = f?['is_active'] ?? true;
    _selectedServiceId = f?['service_id']?.toString();
    _selectedProductId = f?['product_id']?.toString();
    _fetchServicesAndProducts();
  }

  Future<void> _fetchServicesAndProducts() async {
    try {
      final services = await _supabase.from('services').select('id, title').eq('is_active', true);
      final products = await _supabase.from('it_products').select('id, name').eq('is_active', true);
      if (mounted) setState(() {
        _services = List<Map<String, dynamic>>.from(services);
        _products = List<Map<String, dynamic>>.from(products);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _labelCtrl.dispose(); _iconCtrl.dispose(); _colorCtrl.dispose(); _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final payload = {
        'label':      _labelCtrl.text.trim(),
        'icon_name':  _iconCtrl.text.trim(),
        'color_hex':  _colorCtrl.text.trim(),
        'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
        'is_active':  _isActive,
        'updated_at': DateTime.now().toIso8601String(),
        'service_id': _selectedServiceId,
        'product_id': _selectedProductId,
      };
      if (widget.feature == null) {
        await _supabase.from('home_features').insert(payload);
      } else {
        await _supabase.from('home_features').update(payload).eq('id', widget.feature!['id']);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: widget.feature == null ? 'Add Feature' : 'Edit Feature',
      isSaving: _isSaving, onSave: _save,
      saveLabel: widget.feature == null ? 'Add Feature' : 'Update Feature',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormField(label: 'Label *', ctrl: _labelCtrl, required: true, hint: 'e.g. Fast Delivery'),
            const SizedBox(height: 14),
            const Text('Icon Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(controller: _iconCtrl, decoration: const InputDecoration(hintText: 'e.g. flash_on_rounded')),
            const SizedBox(height: 8),
            // Icon quick-select chips
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _iconOptions.map((s) {
                final selected = _iconCtrl.text == s;
                return GestureDetector(
                  onTap: () => setState(() => _iconCtrl.text = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 10, color: selected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _FormField(label: 'Color (hex)', ctrl: _colorCtrl, hint: '#06768D')),
              const SizedBox(width: 12),
              Expanded(child: _FormField(label: 'Sort Order', ctrl: _sortCtrl, hint: '1', keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            // Dropdown for Service
            DropdownButtonFormField<String>(
              value: _selectedServiceId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Link to Service (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('None')),
                ..._services.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text(s['title'] ?? 'Service'))),
              ],
              onChanged: (v) => setState(() => _selectedServiceId = v),
            ),
            const SizedBox(height: 14),
            // Dropdown for Product
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Link to Product (optional)', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('None')),
                ..._products.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['name'] ?? 'Product'))),
              ],
              onChanged: (v) => setState(() => _selectedProductId = v),
            ),
            const SizedBox(height: 14),
            _ToggleRow(label: 'Active (show on home)', value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED FORM SHELL
// ═══════════════════════════════════════════════════════════════
class _FormShell extends StatelessWidget {
  final String title, saveLabel;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSave;

  const _FormShell({required this.title, required this.child, required this.isSaving, required this.onSave, required this.saveLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textHint)),
              ],
            ),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isSaving ? null : onSave,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: isSaving
                      ? LinearGradient(colors: [AppColors.primary.withOpacity(0.5), AppColors.accent.withOpacity(0.5)])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSaving ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: isSaving
                      ? const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 15)),
                        ])
                      : Text(saveLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED FORM WIDGETS
// ═══════════════════════════════════════════════════════════════
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final String? hint;
  final TextInputType? keyboard;

  const _FormField({required this.label, required this.ctrl, this.required = false, this.hint, this.keyboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
          validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary)),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }
}