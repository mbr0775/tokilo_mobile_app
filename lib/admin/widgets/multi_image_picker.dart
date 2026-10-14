// lib/admin/widgets/multi_image_picker.dart
//
// Fixed:
// - No permanent loading placeholder.
// - Upload first, then add image URL.
// - Shows uploading state on the Add button.
// - Handles upload errors clearly.
// - Prevents right-side overflow.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../constants/admin_constants.dart';

class MultiImagePicker extends StatefulWidget {
  final List<String> existingUrls;
  final ValueChanged<List<String>> onChanged;
  final String folder;
  final String? label;

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
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  late List<String> _urls;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.existingUrls);
  }

  @override
  void didUpdateWidget(covariant MultiImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!listEquals(oldWidget.existingUrls, widget.existingUrls)) {
      _urls = List<String>.from(widget.existingUrls);
    }
  }

  String _contentType(String ext) {
    final cleanExt = ext.toLowerCase();

    if (cleanExt == 'jpg' || cleanExt == 'jpeg') return 'image/jpeg';
    if (cleanExt == 'png') return 'image/png';
    if (cleanExt == 'webp') return 'image/webp';
    if (cleanExt == 'gif') return 'image/gif';

    return 'image/jpeg';
  }

  String _safeExtension(String name) {
    if (!name.contains('.')) return 'jpg';

    final ext = name.split('.').last.toLowerCase();

    if (ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif') {
      return ext;
    }

    return 'jpg';
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;

    try {
      final pickedImages = await _picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (pickedImages.isEmpty) return;

      setState(() => _isUploading = true);

      final List<String> uploadedUrls = [];

      for (int i = 0; i < pickedImages.length; i++) {
        final xFile = pickedImages[i];
        final bytes = await xFile.readAsBytes();

        final ext = _safeExtension(xFile.name);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${widget.folder}/${timestamp}_$i.$ext';

        await _supabase.storage.from(AdminConstants.storageBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(ext),
            cacheControl: '3600',
            upsert: true,
          ),
        );

        final publicUrl = _supabase.storage
            .from(AdminConstants.storageBucket)
            .getPublicUrl(fileName);

        uploadedUrls.add(publicUrl);
      }

      if (!mounted) return;

      setState(() {
        _urls.addAll(uploadedUrls);
      });

      widget.onChanged(List<String>.from(_urls));

      _snack(
        uploadedUrls.length == 1
            ? 'Image uploaded successfully'
            : '${uploadedUrls.length} images uploaded successfully',
        error: false,
      );
    } catch (e) {
      _snack('Image upload failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _remove(int index) {
    if (index < 0 || index >= _urls.length) return;

    setState(() {
      _urls.removeAt(index);
    });

    widget.onChanged(List<String>.from(_urls));
  }

  void _snack(String message, {required bool error}) {
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
    final label = widget.label ?? 'Project Images';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderRow(
          label: label,
          isUploading: _isUploading,
          onAdd: _pickAndUpload,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap and hold an image to remove it. Tap + to add more.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (_urls.isEmpty)
          _EmptyImageBox(
            isUploading: _isUploading,
            onTap: _pickAndUpload,
          )
        else
          _ImageGrid(
            urls: _urls,
            isUploading: _isUploading,
            onAdd: _pickAndUpload,
            onRemove: _remove,
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String label;
  final bool isUploading;
  final VoidCallback onAdd;

  const _HeaderRow({
    required this.label,
    required this.isUploading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _AddButton(
              label: compact ? 'Add' : 'Add Images',
              isUploading: isUploading,
              onTap: isUploading ? null : onAdd,
            ),
          ],
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final bool isUploading;
  final VoidCallback? onTap;

  const _AddButton({
    required this.label,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUploading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              const SizedBox(width: 7),
              Text(
                isUploading ? 'Uploading' : label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyImageBox extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onTap;

  const _EmptyImageBox({
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 112,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isUploading
              ? const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Uploading images...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
              : const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.primary,
                size: 30,
              ),
              SizedBox(height: 7),
              Text(
                'Tap to add images',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> urls;
  final bool isUploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImageGrid({
    required this.urls,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 330 ? 2 : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length + 1,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index == urls.length) {
              return _AddGridCell(
                isUploading: isUploading,
                onTap: isUploading ? null : onAdd,
              );
            }

            return _ImageCell(
              url: urls[index],
              onRemove: () => onRemove(index),
            );
          },
        );
      },
    );
  }
}

class _AddGridCell extends StatelessWidget {
  final bool isUploading;
  final VoidCallback? onTap;

  const _AddGridCell({
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isUploading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
              : const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 30,
              ),
              SizedBox(height: 5),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageCell extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _ImageCell({
    required this.url,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return Container(
                    color: AppColors.background,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.textHint,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}