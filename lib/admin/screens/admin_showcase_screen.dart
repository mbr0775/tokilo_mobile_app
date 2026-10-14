// lib/admin/screens/admin_showcase_screen.dart
//
// Project showcase admin screen.
// Fixes:
//   - Add/Edit showcase modal has safe bottom padding.
//   - "Add to Showcase" button no longer hides behind Android navigation.
//   - Uses MultiImagePicker for additional showcase images.
//   - Opens ImageGalleryViewer when tapping gallery button.
//   - No products/tools/business hub content.

import 'dart:typed_data';

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
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _portfolio = [];
  Map<String, List<String>> _extraImages = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final showcaseData = await _supabase
          .from('project_showcase')
          .select()
          .order('sort_order');

      final portfolioData = await _supabase
          .from('portfolio')
          .select('id, title, image_url, category')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final imageData = await _supabase
          .from('project_images')
          .select()
          .filter('showcase_id', 'not.is', null)
          .order('sort_order');

      final Map<String, List<String>> imageMap = {};

      for (final row in imageData as List) {
        final showcaseId = row['showcase_id']?.toString();
        final imageUrl = row['image_url']?.toString();

        if (showcaseId == null || imageUrl == null || imageUrl.isEmpty) {
          continue;
        }

        imageMap.putIfAbsent(showcaseId, () => []).add(imageUrl);
      }

      if (!mounted) return;

      setState(() {
        _items = List<Map<String, dynamic>>.from(showcaseData);
        _portfolio = List<Map<String, dynamic>>.from(portfolioData);
        _extraImages = imageMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _snack('Load error: $e', error: true);
    }
  }

  List<String> _allImages(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final cover = item['image_url']?.toString();
    final extra = _extraImages[id] ?? [];

    if (cover != null && cover.isNotEmpty) {
      return [
        cover,
        ...extra.where((url) => url != cover),
      ];
    }

    return extra;
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await _supabase.from('project_showcase').update({
        'is_active': !current,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      _load();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Remove from Showcase'),
          content: Text('"$title" will be removed from the showcase.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ) ??
        false;

    if (!ok) return;

    try {
      await _supabase.from('project_images').delete().eq('showcase_id', id);
      await _supabase.from('project_showcase').delete().eq('id', id);

      _snack('Removed from showcase');
      _load();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openForm({Map<String, dynamic>? item}) {
    final existingImages = item == null
        ? <String>[]
        : (_extraImages[item['id']?.toString() ?? ''] ?? <String>[]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return ShowcaseFormSheet(
          item: item,
          portfolio: _portfolio,
          existingImages: existingImages,
          onSaved: _load,
        );
      },
    );
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
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          icon: const Icon(
            Icons.add_rounded,
            color: Colors.white,
          ),
          label: const Text(
            'Add to Showcase',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : _items.isEmpty
            ? _emptyState()
            : Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap the gallery icon to view all images. Tap Edit to add more images.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        AppColors.primary.withValues(alpha: 0.90),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _items.length,
                  itemBuilder: (_, index) {
                    return _card(_items[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Showcase Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add projects to the home screen showcase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Untitled';
    final subtitle = item['subtitle']?.toString() ?? '';
    final sortOrder = item['sort_order'] ?? 0;
    final isActive = item['is_active'] as bool? ?? true;

    final images = _allImages(item);
    final cover = images.isNotEmpty ? images.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (cover != null && cover.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Image.network(
                    cover,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return Container(
                        width: double.infinity,
                        height: 180,
                        color: AppColors.border,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      return _fallbackImage();
                    },
                  ),
                )
              else
                _fallbackImage(),

              if (images.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      ImageGalleryViewer.show(
                        context,
                        images: images,
                        initialIndex: 0,
                        title: title,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white70,
                            size: 12,
                          ),
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
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (_) => _toggleActive(id, isActive),
                    ),
                  ],
                ),

                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    _badge(
                      'Order $sortOrder',
                      AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _badge(
                      isActive ? 'Visible' : 'Hidden',
                      isActive ? AppColors.success : AppColors.error,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: images.isEmpty
                          ? null
                          : () {
                        ImageGalleryViewer.show(
                          context,
                          images: images,
                          initialIndex: 0,
                          title: title,
                        );
                      },
                      icon: const Icon(
                        Icons.collections_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openForm(item: item),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(id, title),
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
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

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      child: Icon(
        Icons.photo_library_rounded,
        color: AppColors.primary.withValues(alpha: 0.35),
        size: 46,
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ShowcaseFormSheet extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> portfolio;
  final List<String> existingImages;
  final VoidCallback onSaved;

  const ShowcaseFormSheet({
    super.key,
    this.item,
    required this.portfolio,
    required this.existingImages,
    required this.onSaved,
  });

  @override
  State<ShowcaseFormSheet> createState() => _ShowcaseFormSheetState();
}

class _ShowcaseFormSheetState extends State<ShowcaseFormSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _sortCtrl;

  String? _selectedPortfolioId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;

  Uint8List? _pickedBytes;
  String? _pickedExt;
  String? _existingCoverUrl;
  List<String> _extraImages = [];

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _titleCtrl = TextEditingController(text: item?['title']?.toString() ?? '');
    _subtitleCtrl =
        TextEditingController(text: item?['subtitle']?.toString() ?? '');
    _sortCtrl = TextEditingController(
      text: (item?['sort_order'] ?? 0).toString(),
    );

    _selectedPortfolioId = item?['portfolio_id']?.toString();
    _existingCoverUrl = item?['image_url']?.toString();
    _isActive = item?['is_active'] as bool? ?? true;
    _extraImages = List<String>.from(widget.existingImages);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  String _contentType(String ext) {
    final cleanExt = ext.toLowerCase();

    if (cleanExt == 'jpg' || cleanExt == 'jpeg') return 'image/jpeg';
    if (cleanExt == 'png') return 'image/png';
    if (cleanExt == 'webp') return 'image/webp';
    if (cleanExt == 'gif') return 'image/gif';

    return 'image/$cleanExt';
  }

  void _applyPortfolio(String? portfolioId) {
    if (portfolioId == null) return;

    final match = widget.portfolio.firstWhere(
          (item) => item['id']?.toString() == portfolioId,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) return;

    final title = match['title']?.toString() ?? '';
    final category = match['category']?.toString() ?? '';
    final imageUrl = match['image_url']?.toString() ?? '';

    setState(() {
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = title;
      }

      if (_subtitleCtrl.text.trim().isEmpty && category.isNotEmpty) {
        _subtitleCtrl.text = category;
      }

      if ((_existingCoverUrl == null || _existingCoverUrl!.isEmpty) &&
          imageUrl.isNotEmpty) {
        _existingCoverUrl = imageUrl;
      }
    });
  }

  Future<void> _pickCoverImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1400,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();

      setState(() {
        _pickedBytes = bytes;
        _pickedExt = ext;
      });
    } catch (e) {
      _snack('Image picker failed: $e', error: true);
    }
  }

  Future<String?> _uploadCoverImage() async {
    if (_pickedBytes == null) {
      return _existingCoverUrl;
    }

    setState(() => _isUploading = true);

    try {
      final ext = _pickedExt ?? 'jpg';
      final fileName =
          'showcase/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from(AdminConstants.storageBucket).uploadBinary(
        fileName,
        _pickedBytes!,
        fileOptions: FileOptions(
          contentType: _contentType(ext),
          cacheControl: '3600',
          upsert: false,
        ),
      );

      return _supabase.storage
          .from(AdminConstants.storageBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      _snack('Cover image upload failed: $e', error: true);
      return _existingCoverUrl;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveExtraImages(String showcaseId) async {
    await _supabase.from('project_images').delete().eq('showcase_id', showcaseId);

    if (_extraImages.isEmpty) return;

    final rows = _extraImages.asMap().entries.map((entry) {
      return {
        'showcase_id': showcaseId,
        'image_url': entry.value,
        'sort_order': entry.key,
      };
    }).toList();

    await _supabase.from('project_images').insert(rows);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final coverUrl = await _uploadCoverImage();

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim().isEmpty
            ? null
            : _subtitleCtrl.text.trim(),
        'image_url': coverUrl,
        'portfolio_id': _selectedPortfolioId,
        'sort_order': int.tryParse(_sortCtrl.text.trim()) ?? 0,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      String showcaseId;

      if (widget.item == null) {
        final inserted = await _supabase
            .from('project_showcase')
            .insert(payload)
            .select()
            .single();

        showcaseId = inserted['id'].toString();
        _snack('Added to showcase');
      } else {
        showcaseId = widget.item!['id'].toString();

        await _supabase
            .from('project_showcase')
            .update(payload)
            .eq('id', showcaseId);

        _snack('Showcase updated');
      }

      await _saveExtraImages(showcaseId);

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          keyboardBottom + bottomSafe + 34,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Showcase' : 'Add to Showcase',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textHint,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _coverImagePicker(),

              const SizedBox(height: 18),

              MultiImagePicker(
                existingUrls: _extraImages,
                folder: 'showcase',
                label: 'Additional Showcase Images',
                onChanged: (urls) {
                  setState(() => _extraImages = urls);
                },
              ),

              const SizedBox(height: 20),

              _portfolioDropdown(),

              const SizedBox(height: 18),

              _field(
                label: 'Display Title *',
                controller: _titleCtrl,
                hint: 'e.g. E-Commerce Platform',
                icon: Icons.title_rounded,
                required: true,
              ),

              const SizedBox(height: 16),

              _field(
                label: 'Subtitle / Tags',
                controller: _subtitleCtrl,
                hint: 'e.g. Flutter · Firebase · 2024',
                icon: Icons.label_rounded,
              ),

              const SizedBox(height: 16),

              _field(
                label: 'Sort Order',
                controller: _sortCtrl,
                hint: '0',
                icon: Icons.sort_rounded,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 20),

              _activeSwitch(),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: (_isSaving || _isUploading) ? null : _save,
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: (_isSaving || _isUploading)
                          ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.55),
                          AppColors.accent.withValues(alpha: 0.55),
                        ],
                      )
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: (_isSaving || _isUploading)
                          ? []
                          : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
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
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Saving...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        isEdit ? 'Update Showcase' : 'Add to Showcase',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Image',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: _pickedBytes != null
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    _pickedBytes!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                _removeCoverButton(
                  onTap: () {
                    setState(() {
                      _pickedBytes = null;
                      _pickedExt = null;
                    });
                  },
                ),
              ],
            )
                : (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty)
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    _existingCoverUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                _removeCoverButton(
                  onTap: () {
                    setState(() => _existingCoverUrl = null);
                  },
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap to add cover image',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _removeCoverButton({required VoidCallback onTap}) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _portfolioDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Link to Portfolio Project',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedPortfolioId,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('None'),
            ),
            ...widget.portfolio.map((project) {
              return DropdownMenuItem<String>(
                value: project['id']?.toString(),
                child: Text(
                  project['title']?.toString() ?? 'Untitled Project',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedPortfolioId = value);
            _applyPortfolio(value);
          },
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: required
              ? (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }

            return null;
          }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              color: AppColors.textHint,
              size: 22,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Show on Home Screen',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: _isActive,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _isActive = value);
            },
          ),
        ],
      ),
    );
  }
}