// lib/admin/screens/admin_showcase_screen.dart
//
// UPDATED: ShowcaseFormSheet now includes MultiImagePicker.
// Tapping a showcase card from the list opens ImageGalleryViewer.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_gallery_viewer.dart';
import '../constants/admin_constants.dart';
import '../widgets/multi_image_picker.dart';
import 'admin_shell.dart';

class AdminShowcaseScreen extends StatefulWidget {
  const AdminShowcaseScreen({super.key});
  @override
  State<AdminShowcaseScreen> createState() => _AdminShowcaseScreenState();
}

class _AdminShowcaseScreenState extends State<AdminShowcaseScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items     = [];
  List<Map<String, dynamic>> _portfolio = [];
  Map<String, List<String>>  _extraImgs = {};
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final showcase  = await _supabase.from('project_showcase').select().order('sort_order');
      final portfolio = await _supabase.from('portfolio').select('id, title, image_url, category').eq('is_active', true).order('created_at', ascending: false);
      final imgData   = await _supabase.from('project_images').select()
          .filter('showcase_id', 'not.is', null).order('sort_order');

      final Map<String, List<String>> imgMap = {};
      for (final row in (imgData as List)) {
        final sid = row['showcase_id']?.toString();
        if (sid != null) imgMap.putIfAbsent(sid, () => []).add(row['image_url'] as String);
      }

      if (mounted) setState(() {
        _items     = List<Map<String, dynamic>>.from(showcase);
        _portfolio = List<Map<String, dynamic>>.from(portfolio);
        _extraImgs = imgMap;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); _snack('Load error: $e', error: true); }
    }
  }

  List<String> _allImages(Map<String, dynamic> item) {
    final extra = _extraImgs[item['id']?.toString() ?? ''] ?? [];
    final cover = item['image_url'] as String?;
    if (cover != null && cover.isNotEmpty) return [cover, ...extra.where((u) => u != cover)];
    return extra;
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await _supabase.from('project_showcase').update({'is_active': !current, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
      _load();
    } catch (e) { _snack('Update failed: $e', error: true); }
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from Showcase'),
        content: Text('"$title" will be removed from the home showcase.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, minimumSize: Size.zero),
            child: const Text('Remove', style: TextStyle(color: Colors.white))),
        ],
      )) ?? false;
    if (!ok) return;
    try {
      await _supabase.from('project_images').delete().eq('showcase_id', id);
      await _supabase.from('project_showcase').delete().eq('id', id);
      _snack('Removed from showcase'); _load();
    } catch (e) { _snack('Delete failed: $e', error: true); }
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

  void _openForm({Map<String, dynamic>? item}) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => ShowcaseFormSheet(
        item:      item,
        portfolio: _portfolio,
        existingImages: item != null ? (_extraImgs[item['id']?.toString() ?? ''] ?? []) : [],
        onSaved:   _load,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/showcase',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'Project Showcase (${_items.length})',
          currentPath: '/admin/showcase',
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add to Showcase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _items.isEmpty ? _emptyState()
            : Column(children: [
                Container(margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Tap the gallery icon to view all images. Tap Edit to add more images.',
                        style: TextStyle(fontSize: 12, color: AppColors.primary.withOpacity(0.9), height: 1.4))),
                  ])),
                Expanded(child: RefreshIndicator(onRefresh: _load,
                  child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _card(_items[i])))),
              ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final isActive  = item['is_active'] as bool? ?? true;
    final title     = item['title'] ?? 'Untitled';
    final order     = item['sort_order'] ?? 0;
    final allImages = _allImages(item);
    final cover     = allImages.isNotEmpty ? allImages.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          cover != null && cover.isNotEmpty
              ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(cover, height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback()))
              : _fallback(top: true),
          if (!isActive)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(color: Colors.black54, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
              child: const Center(child: Text('HIDDEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 14))))),
          Positioned(top: 10, right: 10,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Gallery viewer button
              if (allImages.isNotEmpty)
                GestureDetector(
                  onTap: () => ImageGalleryViewer.show(context, images: allImages, initialIndex: 0, title: title),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('${allImages.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 11),
                    ]),
                  )),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text('Order: $order', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
            ])),
        ]),

        Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${allImages.length} image${allImages.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Switch(value: isActive, activeColor: AppColors.primary, onChanged: (_) => _toggleActive(item['id'], isActive)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _badge(isActive ? 'Visible on Home' : 'Hidden', isActive ? AppColors.success : AppColors.error),
              const Spacer(),
              _iconBtn(Icons.edit_rounded, AppColors.primary, () => _openForm(item: item)),
              const SizedBox(width: 6),
              _iconBtn(Icons.delete_rounded, AppColors.error, () => _delete(item['id'], title)),
            ]),
          ])),
      ]),
    );
  }

  Widget _fallback({bool top = false}) => Container(
    height: 110, width: double.infinity,
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07),
        borderRadius: top ? const BorderRadius.vertical(top: Radius.circular(18)) : BorderRadius.circular(18)),
    child: const Icon(Icons.image_rounded, color: AppColors.primary, size: 40));

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34,
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)));

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.photo_library_outlined, size: 80, color: AppColors.primary.withOpacity(0.2)),
    const SizedBox(height: 16),
    const Text('No Showcase Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    const SizedBox(height: 8),
    const Text('Tap + to add projects to the home screen showcase',
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// SHOWCASE FORM SHEET with MultiImagePicker
// ══════════════════════════════════════════════════════════════════════════════
class ShowcaseFormSheet extends StatefulWidget {
  final Map<String, dynamic>?      item;
  final List<Map<String, dynamic>> portfolio;
  final List<String>               existingImages;
  final VoidCallback               onSaved;

  const ShowcaseFormSheet({super.key, this.item, required this.portfolio, required this.existingImages, required this.onSaved});
  @override State<ShowcaseFormSheet> createState() => _ShowcaseFormSheetState();
}

class _ShowcaseFormSheetState extends State<ShowcaseFormSheet> {
  final _supabase = Supabase.instance.client;
  final _picker   = ImagePicker();

  late TextEditingController _titleCtrl, _subtitleCtrl, _sortCtrl;
  String? _selectedPortfolioId;
  bool    _isActive = true, _isSaving = false, _isUploading = false;

  Uint8List? _pickedBytes;
  String?    _pickedExt;
  String?    _existingCoverUrl;
  List<String> _extraImages = [];

  @override
  void initState() {
    super.initState();
    final i       = widget.item;
    _titleCtrl    = TextEditingController(text: i?['title']    ?? '');
    _subtitleCtrl = TextEditingController(text: i?['subtitle'] ?? '');
    _sortCtrl     = TextEditingController(text: (i?['sort_order'] ?? 0).toString());
    _isActive            = i?['is_active']  ?? true;
    _existingCoverUrl    = i?['image_url'];
    _selectedPortfolioId = i?['portfolio_id']?.toString();
    _extraImages         = List<String>.from(widget.existingImages);

    if (_titleCtrl.text.isEmpty && _selectedPortfolioId != null) {
      final match = widget.portfolio.firstWhere((p) => p['id'].toString() == _selectedPortfolioId, orElse: () => {});
      if (match.isNotEmpty) {
        _titleCtrl.text = match['title'] ?? '';
        if (_existingCoverUrl == null || _existingCoverUrl!.isEmpty) _existingCoverUrl = match['image_url'];
      }
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _subtitleCtrl.dispose(); _sortCtrl.dispose(); super.dispose(); }

  void _onPortfolioSelected(String? id) {
    setState(() => _selectedPortfolioId = id);
    if (id == null) return;
    final match = widget.portfolio.firstWhere((p) => p['id'].toString() == id, orElse: () => {});
    if (match.isEmpty) return;
    if (_titleCtrl.text.isEmpty) setState(() => _titleCtrl.text = match['title'] ?? '');
    if ((_existingCoverUrl == null || _existingCoverUrl!.isEmpty) && _pickedBytes == null) {
      setState(() => _existingCoverUrl = match['image_url']);
    }
  }

  Future<void> _pickCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1400);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _pickedBytes = bytes; _pickedExt = picked.name.split('.').last.toLowerCase(); });
  }

  Future<String?> _uploadCover() async {
    if (_pickedBytes == null) return _existingCoverUrl;
    setState(() => _isUploading = true);
    try {
      final ext = _pickedExt ?? 'jpg';
      final fn  = 'showcase/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from(AdminConstants.storageBucket).uploadBinary(fn, _pickedBytes!,
          fileOptions: FileOptions(contentType: 'image/$ext', cacheControl: '3600', upsert: false));
      return _supabase.storage.from(AdminConstants.storageBucket).getPublicUrl(fn);
    } catch (e) { _snack('Cover upload failed: $e', error: true); return _existingCoverUrl; }
    finally { if (mounted) setState(() => _isUploading = false); }
  }

  Future<void> _saveExtraImages(String showcaseId) async {
    await _supabase.from('project_images').delete().eq('showcase_id', showcaseId);
    if (_extraImages.isEmpty) return;
    await _supabase.from('project_images').insert(
      _extraImages.asMap().entries.map((e) => {'showcase_id': showcaseId, 'image_url': e.value, 'sort_order': e.key}).toList());
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) { _snack('Title is required', error: true); return; }
    setState(() => _isSaving = true);
    try {
      final coverUrl = await _uploadCover();
      final payload  = {
        'title':        _titleCtrl.text.trim(),
        'subtitle':     _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
        'sort_order':   int.tryParse(_sortCtrl.text) ?? 0,
        'is_active':    _isActive,
        'image_url':    coverUrl,
        'portfolio_id': _selectedPortfolioId,
        'updated_at':   DateTime.now().toIso8601String(),
      };

      String showcaseId;
      if (widget.item == null) {
        final res = await _supabase.from('project_showcase').insert(payload).select().single();
        showcaseId = res['id'] as String;
        _snack('Added to showcase!');
      } else {
        showcaseId = widget.item!['id'] as String;
        await _supabase.from('project_showcase').update(payload).eq('id', showcaseId);
        _snack('Updated successfully!');
      }

      await _saveExtraImages(showcaseId);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) { _snack('Save failed: $e', error: true); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isEdit ? 'Edit Showcase Item' : 'Add to Showcase',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 18),

        // Cover image picker
        _label('Cover Image'),
        const SizedBox(height: 8),
        GestureDetector(onTap: _pickCover,
          child: Container(height: 160, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)),
            child: _pickedBytes != null
                ? Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
                    Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() { _pickedBytes = null; _pickedExt = null; }),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)))),
                  ])
                : _existingCoverUrl != null && _existingCoverUrl!.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_existingCoverUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 26)),
                        const SizedBox(height: 8),
                        const Text('Tap to add cover image', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ]),
          )),
        const SizedBox(height: 16),

        // Extra images
        MultiImagePicker(existingUrls: _extraImages, folder: 'showcase',
            label: 'Additional Showcase Images', onChanged: (urls) => setState(() => _extraImages = urls)),
        const SizedBox(height: 16),

        // Portfolio link
        _label('Link to Portfolio Project'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPortfolioId, isExpanded: true,
          hint: const Text('None (standalone showcase)'),
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None')),
            ...widget.portfolio.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['title'] ?? 'Project', overflow: TextOverflow.ellipsis))),
          ],
          onChanged: _onPortfolioSelected,
        ),
        const SizedBox(height: 14),

        _label('Display Title *'), const SizedBox(height: 8),
        TextFormField(controller: _titleCtrl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. E-Commerce Platform',
                prefixIcon: Icon(Icons.title_rounded, color: AppColors.textHint, size: 20))),
        const SizedBox(height: 14),

        _label('Subtitle / Tags'), const SizedBox(height: 8),
        TextFormField(controller: _subtitleCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Flutter · Firebase · 2024',
                prefixIcon: Icon(Icons.label_rounded, color: AppColors.textHint, size: 20))),
        const SizedBox(height: 14),

        _label('Sort Order'), const SizedBox(height: 8),
        TextFormField(controller: _sortCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0  (lower = appears first)',
                prefixIcon: Icon(Icons.sort_rounded, color: AppColors.textHint, size: 20))),
        const SizedBox(height: 14),

        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Show on Home Screen', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary)),
            Switch(value: _isActive, activeColor: AppColors.primary, onChanged: (v) => setState(() => _isActive = v)),
          ])),
        const SizedBox(height: 24),

        GestureDetector(onTap: (_isSaving || _isUploading) ? null : _save,
          child: Container(height: 54,
            decoration: BoxDecoration(
              gradient: (_isSaving || _isUploading)
                  ? LinearGradient(colors: [AppColors.primary.withOpacity(0.5), AppColors.accent.withOpacity(0.5)])
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: (_isSaving || _isUploading) ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Center(child: (_isSaving || _isUploading)
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 10), Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 15))])
                : Text(isEdit ? 'Update Showcase' : 'Add to Showcase',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))))),
      ])),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}