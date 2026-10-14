// lib/admin/screens/admin_portfolio_screen.dart
//
// UPDATED:
//  • Tapping a project card opens an image gallery viewer first
//  • Edit form now includes MultiImagePicker for multiple images
//  • Images saved to project_images table (portfolio_id reference)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/image_gallery_viewer.dart';
import '../constants/admin_constants.dart';
import '../models/portfolio_model.dart';
import '../widgets/multi_image_picker.dart';
import 'admin_shell.dart';

class AdminPortfolioScreen extends StatefulWidget {
  const AdminPortfolioScreen({super.key});

  @override
  State<AdminPortfolioScreen> createState() => _AdminPortfolioScreenState();
}

class _AdminPortfolioScreenState extends State<AdminPortfolioScreen> {
  final _supabase = Supabase.instance.client;
  List<PortfolioModel>             _projects       = [];
  Map<String, List<String>>        _projectImages  = {}; // id → [urls]
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('portfolio')
          .select()
          .order('created_at', ascending: false);

      final projects = (data as List)
          .map((e) => PortfolioModel.fromMap(e))
          .toList();

      // Load extra images for all projects
      final imgData = await _supabase
          .from('project_images')
          .select()
          .filter('portfolio_id', 'not.is', null)
          .order('sort_order');

      final Map<String, List<String>> imgMap = {};
      for (final row in (imgData as List)) {
        final pid = row['portfolio_id']?.toString();
        if (pid == null) continue;
        imgMap.putIfAbsent(pid, () => []).add(row['image_url'] as String);
      }

      if (mounted) {
        setState(() {
          _projects      = projects;
          _projectImages = imgMap;
          _isLoading     = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error loading projects: $e', error: true);
      }
    }
  }

  /// All images for a project: cover image + extra images
  List<String> _allImages(PortfolioModel p) {
    final extra = _projectImages[p.id] ?? [];
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
      return [p.imageUrl!, ...extra.where((u) => u != p.imageUrl!)];
    }
    return extra;
  }

  Future<void> _delete(PortfolioModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Project'),
        content: Text('"${p.title}" will be permanently removed.'),
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
    if (!ok) return;
    try {
      await _supabase
          .from('project_images')
          .delete()
          .eq('portfolio_id', p.id);
      await _supabase.from('portfolio').delete().eq('id', p.id);
      _snack('Project deleted');
      _loadProjects();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  Future<void> _toggleActive(PortfolioModel p) async {
    try {
      await _supabase.from('portfolio').update({
        'is_active':  !p.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', p.id);
      _loadProjects();
    } catch (e) {
      _snack('Update failed: $e', error: true);
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
      currentPath: '/admin/portfolio',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'My Projects (${_projects.length})',
          currentPath: '/admin/portfolio',
          actions: [
            IconButton(
              onPressed: _loadProjects,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add Project',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _projects.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _loadProjects,
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _projects.length,
                      itemBuilder: (_, i) => _card(_projects[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline_rounded,
                size: 80,
                color: AppColors.primary.withOpacity(0.25)),
            const SizedBox(height: 16),
            const Text('No Projects Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Tap + to add your first offline project',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _card(PortfolioModel p) {
    final statusColor =
        Color(int.parse('0xFF${p.statusColorHex}'));
    final allImages    = _allImages(p);
    final imageCount   = allImages.length;
    final hasOriginal  = p.originalPrice != null && p.originalPrice!.isNotEmpty;
    final hasAgreed    = p.agreedPrice   != null && p.agreedPrice!.isNotEmpty;

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
          // ── Image with gallery icon ────────────────────────────────
          Stack(
            children: [
              _imageWidget(allImages.isNotEmpty ? allImages.first : null,
                  Icons.work_rounded, AppColors.primary),

              // Image count badge + gallery open button
              if (imageCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => ImageGalleryViewer.show(
                      context,
                      images:       allImages,
                      initialIndex: 0,
                      title:        p.title,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '$imageCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new_rounded,
                              color: Colors.white70, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

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
                          Text(p.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                          if (p.clientName != null &&
                              p.clientName!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 12, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(p.clientName!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                        value: p.isActive,
                        activeColor: AppColors.primary,
                        onChanged: (_) => _toggleActive(p)),
                  ],
                ),

                if (p.description != null && p.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(p.description!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],

                if (hasOriginal || hasAgreed) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (hasOriginal) ...[
                      Text('QAR ${p.originalPrice}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textHint)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 6),
                    ],
                    if (hasAgreed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('QAR ${p.agreedPrice}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    if (p.category != null) ...[
                      _tag(p.category!, AppColors.accent),
                      const SizedBox(width: 6),
                    ],
                    _tagOutlined(p.statusLabel, statusColor),
                    const Spacer(),
                    // View images button
                    if (imageCount > 0)
                      IconButton(
                        onPressed: () => ImageGalleryViewer.show(
                          context,
                          images:       allImages,
                          initialIndex: 0,
                          title:        p.title,
                        ),
                        icon: const Icon(Icons.collections_rounded,
                            color: AppColors.accent, size: 20),
                        tooltip: 'View Images',
                      ),
                    IconButton(
                      onPressed: () => _openForm(project: p),
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    IconButton(
                      onPressed: () => _delete(p),
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

  Widget _tag(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _tagOutlined(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  Widget _imageWidget(String? url, IconData fallbackIcon, Color color) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(18)),
        child: Image.network(url,
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
                            color: AppColors.primary,
                            strokeWidth: 2))),
            errorBuilder: (_, __, ___) =>
                _fallbackImage(fallbackIcon, color)),
      );
    }
    return _fallbackImage(fallbackIcon, color);
  }

  Widget _fallbackImage(IconData icon, Color color) => Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Icon(icon, color: color.withOpacity(0.4), size: 46),
      );

  void _openForm({PortfolioModel? project}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PortfolioFormSheet(
        project:        project,
        existingImages: project != null
            ? (_projectImages[project.id] ?? [])
            : [],
        onSaved: _loadProjects,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PORTFOLIO FORM SHEET  — with MultiImagePicker
// ══════════════════════════════════════════════════════════════════════════════
class PortfolioFormSheet extends StatefulWidget {
  final PortfolioModel? project;
  final List<String>    existingImages;
  final VoidCallback    onSaved;

  const PortfolioFormSheet({
    super.key,
    this.project,
    required this.existingImages,
    required this.onSaved,
  });

  @override
  State<PortfolioFormSheet> createState() => _PortfolioFormSheetState();
}

class _PortfolioFormSheetState extends State<PortfolioFormSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker   = ImagePicker();

  late TextEditingController _titleCtrl;
  late TextEditingController _clientCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _originalPriceCtrl;
  late TextEditingController _agreedPriceCtrl;
  late TextEditingController _techCtrl;
  late TextEditingController _completedAtCtrl;

  String? _category;
  String  _status          = 'completed';
  bool    _isActive        = true;
  File?   _pickedImage;
  String? _existingImageUrl;
  bool    _isSaving        = false;
  bool    _isUploading     = false;

  // Multiple extra images
  List<String> _extraImages = [];

  static const List<String> _categories = [
    'Software Development', 'Retail Technology', 'IT Infrastructure',
    'Cyber Security', 'Physical Security', 'Cloud & DevOps', 'AI & Automation',
  ];
  static const List<String> _statusVals   = ['completed', 'ongoing', 'upcoming'];
  static const List<String> _statusLabels = ['Completed', 'Ongoing', 'Upcoming'];

  @override
  void initState() {
    super.initState();
    final p              = widget.project;
    _titleCtrl           = TextEditingController(text: p?.title         ?? '');
    _clientCtrl          = TextEditingController(text: p?.clientName    ?? '');
    _descCtrl            = TextEditingController(text: p?.description   ?? '');
    _originalPriceCtrl   = TextEditingController(text: p?.originalPrice ?? '');
    _agreedPriceCtrl     = TextEditingController(text: p?.agreedPrice   ?? '');
    _techCtrl            = TextEditingController(text: p?.technologies  ?? '');
    _completedAtCtrl     = TextEditingController(text: p?.completedAt   ?? '');
    _category            = p?.category;
    _status              = p?.status ?? 'completed';
    _isActive            = p?.isActive ?? true;
    _existingImageUrl    = p?.imageUrl;
    _extraImages         = List<String>.from(widget.existingImages);
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _clientCtrl.dispose(); _descCtrl.dispose();
    _originalPriceCtrl.dispose(); _agreedPriceCtrl.dispose();
    _techCtrl.dispose(); _completedAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadCoverImage() async {
    if (_pickedImage == null) return _existingImageUrl;
    setState(() => _isUploading = true);
    try {
      final ext      = _pickedImage!.path.split('.').last;
      final fileName =
          'portfolio/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes    = await _pickedImage!.readAsBytes();
      await _supabase.storage.from(AdminConstants.storageBucket).uploadBinary(
        fileName, bytes,
        fileOptions: FileOptions(
            contentType: 'image/$ext',
            cacheControl: '3600',
            upsert: false),
      );
      return _supabase.storage
          .from(AdminConstants.storageBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      _snack('Cover image upload failed: $e', error: true);
      return _existingImageUrl;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveExtraImages(String projectId) async {
    // Delete old extra images
    await _supabase
        .from('project_images')
        .delete()
        .eq('portfolio_id', projectId);

    if (_extraImages.isEmpty) return;

    // Insert new ones
    final rows = _extraImages.asMap().entries.map((e) => {
          'portfolio_id': projectId,
          'image_url':    e.value,
          'sort_order':   e.key,
        }).toList();
    await _supabase.from('project_images').insert(rows);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadCoverImage();
      final payload  = <String, dynamic>{
        'title':       _titleCtrl.text.trim(),
        'client_name': _clientCtrl.text.trim().isEmpty
            ? null : _clientCtrl.text.trim(),
        'category':    _category,
        'description': _descCtrl.text.trim().isEmpty
            ? null : _descCtrl.text.trim(),
        'image_url':   imageUrl,
        'technologies':_techCtrl.text.trim().isEmpty
            ? null : _techCtrl.text.trim(),
        'status':      _status,
        'completed_at':_completedAtCtrl.text.trim().isEmpty
            ? null : _completedAtCtrl.text.trim(),
        'is_active':   _isActive,
        'updated_at':  DateTime.now().toIso8601String(),
      };
      final orig = _originalPriceCtrl.text.trim();
      final agrd = _agreedPriceCtrl.text.trim();
      if (orig.isNotEmpty) payload['original_price'] = orig;
      if (agrd.isNotEmpty) payload['agreed_price']   = agrd;

      String projectId;
      if (widget.project == null) {
        final res =
            await _supabase.from('portfolio').insert(payload).select().single();
        projectId = res['id'] as String;
        _snack('Project added successfully!');
      } else {
        projectId = widget.project!.id;
        await _supabase
            .from('portfolio')
            .update(payload)
            .eq('id', projectId);
        _snack('Project updated successfully!');
      }

      await _saveExtraImages(projectId);

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
    final isEdit = widget.project != null;
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
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? 'Edit Project' : 'Add New Project',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 18),

              // ── Cover image ─────────────────────────────────────────
              _buildCoverImagePicker(),
              const SizedBox(height: 16),

              // ── Additional images (MultiImagePicker) ────────────────
              MultiImagePicker(
                existingUrls: _extraImages,
                folder:       'portfolio',
                label:        'Additional Project Images',
                onChanged:    (urls) => setState(() => _extraImages = urls),
              ),
              const SizedBox(height: 16),

              // ── Project Name ────────────────────────────────────────
              _label('Project Name *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. E-Commerce Mobile App',
                  prefixIcon: Icon(Icons.work_outline_rounded,
                      color: AppColors.textHint, size: 20),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Project name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // ── Client Name ─────────────────────────────────────────
              _label('Client Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _clientCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Al Meera Trading',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textHint, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // ── Category ────────────────────────────────────────────
              _label('Category'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                hint: const Text('Select category'),
                isExpanded: true,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14)),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 14),

              // ── Description ─────────────────────────────────────────
              _label('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Brief description of the project...'),
              ),
              const SizedBox(height: 14),

              // ── Pricing ─────────────────────────────────────────────
              _label('Pricing'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _originalPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Original (QAR)',
                      hintText: 'e.g. 15000',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _agreedPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Agreed (QAR)',
                      hintText: 'e.g. 10000',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // ── Technologies ────────────────────────────────────────
              _label('Technologies Used'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _techCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Flutter, Firebase, Node.js',
                  prefixIcon: Icon(Icons.code_rounded,
                      color: AppColors.textHint, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // ── Status ──────────────────────────────────────────────
              _label('Project Status'),
              const SizedBox(height: 8),
              Row(
                children: List.generate(_statusVals.length, (i) {
                  final val      = _statusVals[i];
                  final label    = _statusLabels[i];
                  final selected = _status == val;
                  final colors   = [
                    AppColors.success,
                    const Color(0xFF3B82F6),
                    const Color(0xFFF59E0B)
                  ];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _status = val),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i < _statusVals.length - 1 ? 8 : 0),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors[i].withOpacity(0.12)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: selected
                                  ? colors[i]
                                  : AppColors.border,
                              width: selected ? 1.5 : 1),
                        ),
                        child: Center(
                          child: Text(label,
                              style: TextStyle(
                                  color: selected
                                      ? colors[i]
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // ── Completed date ──────────────────────────────────────
              _label('Completion Date'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _completedAtCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. 2024-06-15',
                  prefixIcon: Icon(Icons.calendar_today_rounded,
                      color: AppColors.textHint, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // ── Active toggle ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active (visible in app)',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                    Switch(
                        value: _isActive,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isActive = v)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Save button ─────────────────────────────────────────
              GestureDetector(
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
                                      color: Colors.white,
                                      strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Saving...',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15)),
                            ])
                        : Text(
                            isEdit ? 'Update Project' : 'Add Project',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Cover Image'),
        const SizedBox(height: 4),
        const Text('Main image shown on the card.',
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 1.5),
            ),
            child: _pickedImage != null
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
                          onTap: () =>
                              setState(() => _pickedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16),
                          ),
                        )),
                  ])
                : _existingImageUrl != null &&
                        _existingImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(_existingImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(height: 8),
                          const Text('Tap to add cover image',
                              style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 13)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));
}