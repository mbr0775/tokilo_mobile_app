// lib/admin/screens/admin_services_screen.dart
//
// UPDATED: Added Price Label, Price (raw), and Duration fields
// to the service form so marketplace can show real pricing.
//
// New Supabase columns needed (run migration in service_model.dart header):
//   services.price        TEXT
//   services.price_label  TEXT
//   services.duration     TEXT

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../constants/admin_constants.dart';
import '../models/service_model.dart';
import 'admin_shell.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final _supabase = Supabase.instance.client;
  List<ServiceModel> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('services')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _services  = (data as List).map((e) => ServiceModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error loading services: $e', error: true);
      }
    }
  }

  Future<void> _delete(ServiceModel s) async {
    final ok = await _confirm('Delete Service',
        '"${s.title}" will be permanently removed.');
    if (!ok) return;
    try {
      if (s.imageUrl != null && s.imageUrl!.isNotEmpty) {
        final path = _pathFrom(s.imageUrl!);
        if (path != null) {
          await _supabase.storage
              .from(AdminConstants.storageBucket)
              .remove([path]);
        }
      }
      await _supabase.from('services').delete().eq('id', s.id);
      _snack('Service deleted');
      _loadServices();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  Future<void> _toggleActive(ServiceModel s) async {
    try {
      await _supabase.from('services').update({
        'is_active':  !s.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', s.id);
      _loadServices();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  String? _pathFrom(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      final i    = segs.indexOf(AdminConstants.storageBucket);
      if (i >= 0 && i < segs.length - 1) return segs.sublist(i + 1).join('/');
    } catch (_) {}
    return null;
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

  Future<bool> _confirm(String title, String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, minimumSize: Size.zero),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ) ?? false;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/services',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'Services (${_services.length})',
          currentPath: '/admin/services',
          actions: [
            IconButton(
              onPressed: _loadServices,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add Service',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _services.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _loadServices,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _services.length,
                      itemBuilder: (_, i) => _card(_services[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.design_services_outlined,
                size: 80, color: AppColors.primary.withOpacity(0.25)),
            const SizedBox(height: 16),
            const Text('No Services Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Tap + to add your first service',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _card(ServiceModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imageWidget(s.imageUrl, Icons.design_services_rounded, AppColors.primary),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                          if (s.category != null) ...[
                            const SizedBox(height: 3),
                            Text(s.category!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isActive,
                      activeColor: AppColors.primary,
                      onChanged: (_) => _toggleActive(s),
                    ),
                  ],
                ),
                if (s.description != null && s.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(s.description!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                // ── NEW: price + duration row ──────────────────
                Row(
                  children: [
                    if (s.displayPrice.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.displayPrice,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (s.duration != null && s.duration!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 11, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              s.duration!,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (s.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.tag!,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: s.isActive
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.isActive ? 'Active' : 'Hidden',
                        style: TextStyle(
                          color: s.isActive
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _openForm(service: s),
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    IconButton(
                      onPressed: () => _delete(s),
                      icon: const Icon(Icons.delete_rounded,
                          color: AppColors.error, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageWidget(String? url, IconData fallbackIcon, Color color) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Image.network(
          url,
          height: 170,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  height: 170,
                  color: AppColors.border,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))),
          errorBuilder: (_, __, ___) => _fallbackImage(fallbackIcon, color),
        ),
      );
    }
    return _fallbackImage(fallbackIcon, color);
  }

  Widget _fallbackImage(IconData icon, Color color) => Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Icon(icon, color: color.withOpacity(0.4), size: 46),
      );

  void _openForm({ServiceModel? service}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ServiceFormSheet(service: service, onSaved: _loadServices),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE FORM BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════
class ServiceFormSheet extends StatefulWidget {
  final ServiceModel? service;
  final VoidCallback  onSaved;

  const ServiceFormSheet({super.key, this.service, required this.onSaved});

  @override
  State<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<ServiceFormSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker   = ImagePicker();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;       // NEW
  late TextEditingController _priceLabelCtrl;  // NEW
  late TextEditingController _durationCtrl;    // NEW

  String? _category;
  String? _tag;
  bool    _isActive         = true;
  File?   _pickedImage;
  String? _existingImageUrl;
  bool    _isSaving         = false;
  bool    _isUploading      = false;

  @override
  void initState() {
    super.initState();
    final s           = widget.service;
    _titleCtrl        = TextEditingController(text: s?.title       ?? '');
    _descCtrl         = TextEditingController(text: s?.description ?? '');
    _priceCtrl        = TextEditingController(text: s?.price       ?? '');
    _priceLabelCtrl   = TextEditingController(text: s?.priceLabel  ?? '');
    _durationCtrl     = TextEditingController(text: s?.duration    ?? '');
    _category         = s?.category;
    _tag              = s?.tag;
    _isActive         = s?.isActive ?? true;
    _existingImageUrl = s?.imageUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _priceLabelCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _existingImageUrl;
    setState(() => _isUploading = true);
    try {
      final ext      = _pickedImage!.path.split('.').last;
      final fileName =
          '${AdminConstants.servicesFolder}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes    = await _pickedImage!.readAsBytes();
      await _supabase.storage
          .from(AdminConstants.storageBucket)
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(
                  contentType: 'image/$ext',
                  cacheControl: '3600',
                  upsert: false));
      return _supabase.storage
          .from(AdminConstants.storageBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      _snack('Image upload failed: $e', error: true);
      return _existingImageUrl;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImage();
      final payload  = {
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category':    _category,
        'tag':         _tag,
        'image_url':   imageUrl,
        'is_active':   _isActive,
        'updated_at':  DateTime.now().toIso8601String(),
        // ── NEW fields ──────────────────────────────────────
        'price':       _priceCtrl.text.trim().isEmpty
                           ? null
                           : _priceCtrl.text.trim(),
        'price_label': _priceLabelCtrl.text.trim().isEmpty
                           ? null
                           : _priceLabelCtrl.text.trim(),
        'duration':    _durationCtrl.text.trim().isEmpty
                           ? null
                           : _durationCtrl.text.trim(),
      };
      if (widget.service == null) {
        await _supabase.from('services').insert(payload);
        _snack('Service added successfully!');
      } else {
        await _supabase
            .from('services')
            .update(payload)
            .eq('id', widget.service!.id);
        _snack('Service updated successfully!');
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final isEdit = widget.service != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ────────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Edit Service' : 'Add New Service',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Image ─────────────────────────────────────────
              _buildImagePicker(),
              const SizedBox(height: 16),

              // ── Title ─────────────────────────────────────────
              _label('Service Title *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Web Development',
                  prefixIcon: Icon(Icons.design_services_outlined,
                      color: AppColors.textHint, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // ── Description ───────────────────────────────────
              _label('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Brief description of the service...'),
              ),
              const SizedBox(height: 14),

              // ── Price row (NEW) ───────────────────────────────
              _label('Pricing'),
              const SizedBox(height: 4),
              Text(
                'Price Label is shown in the marketplace. Leave blank for "Get Quote".',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceLabelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. From QAR 1,500',
                        labelText: 'Price Label',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1500',
                        labelText: 'Price (QAR)',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Duration (NEW) ────────────────────────────────
              _label('Duration / Delivery Time'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. 3–5 days · 1 week · On-site',
                  prefixIcon: Icon(Icons.schedule_rounded,
                      color: AppColors.textHint, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // ── Category + Tag ────────────────────────────────
              Row(
                children: [
                  Expanded(child: _buildCategoryDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTagDropdown()),
                ],
              ),
              const SizedBox(height: 14),

              // ── Active toggle ─────────────────────────────────
              _buildToggleRow(
                label: 'Active (visible in app)',
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 24),

              // ── Save button ───────────────────────────────────
              _buildSaveButton(isEdit),
            ],
          ),
        ),
      ),
    );
  }

  // ── Image picker (unchanged) ────────────────────────────────────────────
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Service Image'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 1.5),
            ),
            child: _isUploading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('Uploading image...',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )
                : _pickedImage != null
                    ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_pickedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _pickedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8, right: 8,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Change',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ])
                    : _existingImageUrl != null &&
                            _existingImageUrl!.isNotEmpty
                        ? Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(_existingImageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity),
                            ),
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change Image',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ])
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: 10),
                              const Text('Tap to upload image',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('JPG, PNG supported',
                                  style: TextStyle(
                                      color: AppColors.textHint, fontSize: 12)),
                            ],
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Category'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            hint: const Text('Category'),
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            items: AdminConstants.serviceCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
        ],
      );

  Widget _buildTagDropdown() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Tag'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _tag,
            isExpanded: true,
            hint: const Text('Tag'),
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Tag')),
              ...AdminConstants.serviceTags
                  .map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: (v) => setState(() => _tag = v),
          ),
        ],
      );

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.textPrimary)),
            Switch(
                value: value,
                activeColor: AppColors.primary,
                onChanged: onChanged),
          ],
        ),
      );

  Widget _buildSaveButton(bool isEdit) => GestureDetector(
        onTap: (_isSaving || _isUploading) ? null : _save,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: (_isSaving || _isUploading)
                ? LinearGradient(colors: [
                    AppColors.primary.withOpacity(0.5),
                    AppColors.accent.withOpacity(0.5)
                  ])
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: (_isSaving || _isUploading)
                ? []
                : [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Center(
            child: (_isSaving || _isUploading)
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Saving...',
                          style:
                              TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                  )
                : Text(isEdit ? 'Update Service' : 'Add Service',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
          ),
        ),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));
}