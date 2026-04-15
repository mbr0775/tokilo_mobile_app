// lib/admin/widgets/multi_image_picker.dart
//
// Reusable widget for picking + uploading multiple images.
// Used in:
//   • PortfolioFormSheet  (lib/admin/screens/admin_portfolio_screen.dart)
//   • ShowcaseFormSheet   (lib/admin/screens/admin_showcase_screen.dart)
//
// Stores uploaded URLs in a List<String>.
// Caller provides [existingUrls] on edit, and a callback [onChanged]
// whenever the list changes.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../constants/admin_constants.dart';

class MultiImagePicker extends StatefulWidget {
  final List<String>             existingUrls;
  final ValueChanged<List<String>> onChanged;
  final String                   folder;       // e.g. 'portfolio' or 'showcase'
  final String?                  label;

  const MultiImagePicker({
    super.key,
    required this.existingUrls,
    required this.onChanged,
    required this.folder,
    this.label,
  });

  @override
  State<MultiImagePicker> createState() => _MultiImagePickerState();
}

class _MultiImagePickerState extends State<MultiImagePicker> {
  final _supabase = Supabase.instance.client;
  final _picker   = ImagePicker();

  late List<String> _urls;
  final List<bool>  _uploading = [];
  bool _pickingMultiple = false;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.existingUrls);
    _uploading.addAll(List.filled(_urls.length, false));
  }

  Future<void> _pickAndUpload() async {
    setState(() => _pickingMultiple = true);
    try {
      final picked = await _picker.pickMultiImage(
          imageQuality: 80, maxWidth: 1400);
      if (picked.isEmpty) return;

      for (final xFile in picked) {
        final bytes = await xFile.readAsBytes();
        final ext   = xFile.name.split('.').last.toLowerCase();
        final idx   = _urls.length;

        setState(() {
          _urls.add('');           // placeholder
          _uploading.add(true);
        });

        try {
          final fileName =
              '${widget.folder}/${DateTime.now().millisecondsSinceEpoch}_$idx.$ext';
          await _supabase.storage
              .from(AdminConstants.storageBucket)
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                    contentType: 'image/$ext',
                    cacheControl: '3600',
                    upsert: false),
              );
          final url = _supabase.storage
              .from(AdminConstants.storageBucket)
              .getPublicUrl(fileName);

          if (mounted) {
            setState(() {
              _urls[idx]      = url;
              _uploading[idx] = false;
            });
            widget.onChanged(List<String>.from(_urls));
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _urls.removeAt(idx);
              _uploading.removeAt(idx);
            });
            _snack('Upload failed: $e');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _pickingMultiple = false);
    }
  }

  void _remove(int i) {
    setState(() {
      _urls.removeAt(i);
      _uploading.removeAt(i);
    });
    widget.onChanged(List<String>.from(_urls));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row ────────────────────────────────────────────────
        Row(
          children: [
            Text(
              widget.label ?? 'Project Images',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _pickingMultiple ? null : _pickAndUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pickingMultiple
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary))
                        : const Icon(Icons.add_photo_alternate_rounded,
                            size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Add Images',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap and hold an image to remove it. Tap + to add more.',
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // ── Image grid ───────────────────────────────────────────────
        if (_urls.isEmpty)
          GestureDetector(
            onTap: _pickAndUpload,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.25),
                    width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.primary.withOpacity(0.5), size: 28),
                  const SizedBox(height: 6),
                  const Text('Tap to add images',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _urls.length + 1, // +1 for the add button
            itemBuilder: (_, i) {
              // Last cell = add more button
              if (i == _urls.length) {
                return GestureDetector(
                  onTap: _pickAndUpload,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: AppColors.primary, size: 24),
                        const SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }

              final url        = _urls[i];
              final isUploading = _uploading[i];

              return GestureDetector(
                onLongPress: () => _remove(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      isUploading || url.isEmpty
                          ? Container(
                              color: AppColors.border,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                ),
                              ),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.border,
                                child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: AppColors.textHint),
                              ),
                            ),

                      // Remove button (top-right)
                      if (!isUploading && url.isNotEmpty)
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _remove(i),
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),

                      // Index badge
                      if (!isUploading && url.isNotEmpty)
                        Positioned(
                          bottom: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}