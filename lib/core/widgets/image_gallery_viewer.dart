// lib/core/widgets/image_gallery_viewer.dart
//
// Full-screen swipeable image gallery.
// Used by:
//   • PortfolioScreen  — tap image icon on a card
//   • AdminPortfolioScreen — tap project from list
//   • HomeShowcaseSection  — tap a showcase card
//
// Usage:
//   ImageGalleryViewer.show(context, images: [...], initialIndex: 0);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? title;

  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title,
  });

  /// Convenience method — opens the gallery as a full-screen route.
  static void show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? title,
  }) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => ImageGalleryViewer(
          images: images,
          initialIndex: initialIndex,
          title: title,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    // Go full immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Swipeable pages ────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _ZoomableImage(url: widget.images[i]),
          ),

          // ── Top bar ────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Close
                    _GlassBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    // Title / counter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            '${_current + 1} / ${widget.images.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Dot indicators ─────────────────────────────────────────
          if (widget.images.length > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final active = _current == i;
                  return AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // ── Left / Right arrows (only if >1 image) ─────────────────
          if (widget.images.length > 1) ...[
            // Left
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current > 0
                    ? _GlassBtn(
                        icon: Icons.chevron_left_rounded,
                        size: 28,
                        onTap: () => _pageCtrl.previousPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // Right
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _current < widget.images.length - 1
                    ? _GlassBtn(
                        icon: Icons.chevron_right_rounded,
                        size: 28,
                        onTap: () => _pageCtrl.nextPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Zoomable image page ────────────────────────────────────────────────────
class _ZoomableImage extends StatelessWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                color: Colors.white,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white24, size: 56),
              const SizedBox(height: 12),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Frosted-glass circular button ─────────────────────────────────────────
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _GlassBtn({required this.icon, required this.onTap, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final label = switch (icon) {
      Icons.close_rounded => 'Close image gallery',
      Icons.chevron_left_rounded => 'Previous image',
      _ => 'Next image',
    };
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: Colors.white.withValues(alpha: .15)),
      ),
      icon: Icon(icon, size: size),
    );
  }
}
