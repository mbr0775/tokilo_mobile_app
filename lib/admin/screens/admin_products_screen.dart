// lib/admin/screens/admin_products_screen.dart
//
// FIX: Replaced Image.file + File with Image.memory + Uint8List
//      so image preview works on Flutter Web (Image.file is not supported on web).

import 'package:flutter/foundation.dart';   // kIsWeb + Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../constants/admin_constants.dart';
import '../models/product_model.dart';
import 'admin_shell.dart';

enum _ViewMode { list, grid2, grid3 }

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _supabase = Supabase.instance.client;
  List<ProductModel> _products = [];
  bool _isLoading = true;
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('it_products')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _products = (data as List).map((e) => ProductModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error loading products: $e', error: true);
      }
    }
  }

  Future<void> _delete(ProductModel p) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Product'),
            content: Text('"${p.name}" will be permanently removed.'),
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
      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
        final path = _pathFrom(p.imageUrl!);
        if (path != null) {
          await _supabase.storage.from(AdminConstants.storageBucket).remove([path]);
        }
      }
      await _supabase.from('it_products').delete().eq('id', p.id);
      _snack('Product deleted');
      _loadProducts();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  Future<void> _toggleActive(ProductModel p) async {
    try {
      await _supabase.from('it_products').update({
        'is_active': !p.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', p.id);
      _loadProducts();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _toggleStock(ProductModel p) async {
    try {
      await _supabase.from('it_products').update({
        'in_stock': !p.inStock,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', p.id);
      _loadProducts();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  String? _pathFrom(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      final i = segs.indexOf(AdminConstants.storageBucket);
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

  Widget _viewToggle() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn(Icons.view_list_rounded, _ViewMode.list),
          _toggleBtn(Icons.grid_view_rounded, _ViewMode.grid2),
          _toggleBtn(Icons.grid_on_rounded, _ViewMode.grid3),
        ],
      ),
    );
  }

  Widget _toggleBtn(IconData icon, _ViewMode mode) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/products',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'IT Products (${_products.length})',
          currentPath: '/admin/products',
          actions: [
            _viewToggle(),
            IconButton(onPressed: _loadProducts, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: const Color(0xFF8B5CF6),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _products.isEmpty
                ? _emptyState()
                : RefreshIndicator(onRefresh: _loadProducts, child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_viewMode == _ViewMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _products.length,
        itemBuilder: (_, i) => _listCard(_products[i]),
      );
    }
    final cols   = _viewMode == _ViewMode.grid2 ? 2 : 3;
    final extent = _viewMode == _ViewMode.grid2 ? 220.0 : 190.0;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: extent,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) => _gridCard(_products[i]),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.devices_outlined, size: 80, color: const Color(0xFF8B5CF6).withOpacity(0.25)),
      const SizedBox(height: 16),
      const Text('No Products Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Tap + to add your first product', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _listCard(ProductModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _imageWidget(p.imageUrl, Icons.devices_rounded, const Color(0xFF8B5CF6)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                if (p.brand != null) ...[
                  const SizedBox(height: 3),
                  Text(p.brand!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ])),
              Switch(value: p.isActive, activeColor: AppColors.primary, onChanged: (_) => _toggleActive(p)),
            ]),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (p.price != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(p.price!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => _toggleStock(p), child: _stockBadge(p.inStock)),
              const Spacer(),
              IconButton(onPressed: () => _openForm(product: p), icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20)),
              IconButton(onPressed: () => _delete(p), icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _gridCard(ProductModel p) {
    final isCompact = _viewMode == _ViewMode.grid3;
    return GestureDetector(
      onTap: () => _openForm(product: p),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: isCompact ? 90 : 110,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackGrid(const Color(0xFF8B5CF6), Icons.devices_rounded))
                    : _fallbackGrid(const Color(0xFF8B5CF6), Icons.devices_rounded),
                if (!p.isActive)
                  Container(color: Colors.black.withOpacity(0.45),
                    child: const Center(child: Text('INACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)))),
                Positioned(top: 6, right: 6, child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: p.inStock ? AppColors.success : AppColors.error, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isCompact ? 11 : 12, color: AppColors.textPrimary, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    if (p.price != null)
                      Expanded(child: Text(p.price!, style: TextStyle(fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w800, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => _delete(p), child: Icon(Icons.delete_outline_rounded, size: isCompact ? 14 : 16, color: AppColors.error.withOpacity(0.6))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stockBadge(bool inStock) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: inStock ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(inStock ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: inStock ? AppColors.success : AppColors.error),
      const SizedBox(width: 4),
      Text(inStock ? 'In Stock' : 'Out of Stock', style: TextStyle(color: inStock ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _imageWidget(String? url, IconData fallbackIcon, Color color) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Image.network(url, height: 170, width: double.infinity, fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null ? child
              : Container(height: 170, color: AppColors.border, child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
          errorBuilder: (_, __, ___) => _fallbackImage(fallbackIcon, color)),
      );
    }
    return _fallbackImage(fallbackIcon, color);
  }

  Widget _fallbackImage(IconData icon, Color color) => Container(
    height: 110, width: double.infinity,
    decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
    child: Icon(icon, color: color.withOpacity(0.4), size: 46),
  );

  Widget _fallbackGrid(Color color, IconData icon) => Container(
    color: color.withOpacity(0.07),
    child: Center(child: Icon(icon, color: color.withOpacity(0.4), size: 32)),
  );

  void _openForm({ProductModel? product}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => ProductFormSheet(product: product, onSaved: _loadProducts),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT FORM  — uses Uint8List instead of File for web compatibility
// ══════════════════════════════════════════════════════════════════════════════
class ProductFormSheet extends StatefulWidget {
  final ProductModel? product;
  final VoidCallback onSaved;
  const ProductFormSheet({super.key, this.product, required this.onSaved});

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker   = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;

  String?    _category;
  bool       _isActive       = true;
  bool       _inStock        = true;

  // ── Web-compatible image state ──────────────────────────────────────────
  Uint8List? _pickedBytes;     // replaces File? _pickedImage
  String?    _pickedExtension;
  String?    _existingImageUrl;

  bool _isSaving   = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl  = TextEditingController(text: p?.name        ?? '');
    _brandCtrl = TextEditingController(text: p?.brand       ?? '');
    _priceCtrl = TextEditingController(text: p?.price       ?? '');
    _descCtrl  = TextEditingController(text: p?.description ?? '');
    _category          = p?.category;
    _isActive          = p?.isActive  ?? true;
    _inStock           = p?.inStock   ?? true;
    _existingImageUrl  = p?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Pick image → read as bytes (works on web + mobile) ─────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext   = picked.name.split('.').last.toLowerCase();
    setState(() {
      _pickedBytes     = bytes;
      _pickedExtension = ext;
    });
  }

  // ── Upload bytes to Supabase storage ───────────────────────────────────
  Future<String?> _uploadImage() async {
    if (_pickedBytes == null) return _existingImageUrl;
    setState(() => _isUploading = true);
    try {
      final ext      = _pickedExtension ?? 'jpg';
      final fileName = '${AdminConstants.productsFolder}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from(AdminConstants.storageBucket)
          .uploadBinary(
            fileName,
            _pickedBytes!,
            fileOptions: FileOptions(contentType: 'image/$ext', cacheControl: '3600', upsert: false),
          );
      return _supabase.storage.from(AdminConstants.storageBucket).getPublicUrl(fileName);
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
        'name':        _nameCtrl.text.trim(),
        'brand':       _brandCtrl.text.trim(),
        'category':    _category,
        'description': _descCtrl.text.trim(),
        'price':       _priceCtrl.text.trim(),
        'image_url':   imageUrl,
        'in_stock':    _inStock,
        'is_active':   _isActive,
        'updated_at':  DateTime.now().toIso8601String(),
      };
      if (widget.product == null) {
        await _supabase.from('it_products').insert(payload);
        _snack('Product added successfully!');
      } else {
        await _supabase.from('it_products').update(payload).eq('id', widget.product!.id);
        _snack('Product updated successfully!');
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
    final isEdit = widget.product != null;
    const purple = Color(0xFF8B5CF6);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isEdit ? 'Edit IT Product' : 'Add IT Product',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textHint)),
            ]),
            const SizedBox(height: 18),

            // ── Image picker ──────────────────────────────────────────────
            _buildImagePicker(purple),
            const SizedBox(height: 16),

            // ── Name ──────────────────────────────────────────────────────
            _label('Product Name *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. CCTV System',
                prefixIcon: Icon(Icons.devices_outlined, color: AppColors.textHint, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Brand'),
                const SizedBox(height: 8),
                TextFormField(controller: _brandCtrl, decoration: const InputDecoration(hintText: 'e.g. Hikvision')),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Price'),
                const SizedBox(height: 8),
                TextFormField(controller: _priceCtrl, decoration: const InputDecoration(hintText: 'e.g. QAR 450')),
              ])),
            ]),
            const SizedBox(height: 14),

            _label('Category'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              hint: const Text('Select category'),
              isExpanded: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: AdminConstants.productCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),

            _label('Description'),
            const SizedBox(height: 8),
            TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe this product...')),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: _toggleTile(label: 'Active',    value: _isActive, onChanged: (v) => setState(() => _isActive = v))),
              const SizedBox(width: 12),
              Expanded(child: _toggleTile(label: 'In Stock',  value: _inStock,  onChanged: (v) => setState(() => _inStock  = v))),
            ]),
            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────────────
            GestureDetector(
              onTap: (_isSaving || _isUploading) ? null : _save,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: (_isSaving || _isUploading)
                      ? const LinearGradient(colors: [Color(0xFFB39DDB), Color(0xFF80DEEA)])
                      : const LinearGradient(colors: [purple, Color(0xFF06768D)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_isSaving || _isUploading) ? [] : [BoxShadow(color: purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: (_isSaving || _isUploading)
                      ? const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 15)),
                        ])
                      : Text(isEdit ? 'Update Product' : 'Add Product',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Image picker widget — uses Image.memory for web compatibility ────────
  Widget _buildImagePicker(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Product Image'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 170, width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
            ),
            child: _isUploading
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 10),
                    Text('Uploading...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]))
                // ── NEW: show bytes preview (works on web) ──────────────
                : _pickedBytes != null
                    ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                        ),
                        Positioned(top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() { _pickedBytes = null; _pickedExtension = null; }),
                            child: Container(padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
                          )),
                        Positioned(bottom: 8, right: 8,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ])),
                          )),
                      ])
                    : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                        ? Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(_existingImageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            ),
                            Positioned(bottom: 8, right: 8,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ])),
                              )),
                          ])
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(width: 56, height: 56,
                              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.add_photo_alternate_rounded, color: accentColor, size: 28)),
                            const SizedBox(height: 10),
                            const Text('Tap to upload image', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('JPG, PNG supported', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                          ]),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  Widget _toggleTile({required String label, required bool value, required ValueChanged<bool> onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      );
}