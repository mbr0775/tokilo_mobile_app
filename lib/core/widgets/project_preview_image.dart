import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// App screenshots retain their full composition inside a bounded preview.
class ProjectPreviewImage extends StatelessWidget {
  const ProjectPreviewImage({
    super.key,
    required this.url,
    required this.label,
    this.height = 192,
  });
  final String url;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: ColoredBox(
      color: const Color(0xFFEAF1F2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Image.network(
          url,
          semanticLabel: label,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}
