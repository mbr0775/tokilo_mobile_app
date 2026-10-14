import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../admin/navigation/admin_router.dart';
import 'image_gallery_viewer.dart';
import 'top_status_actions.dart';
import 'tokilo_motion.dart';

class StudioColors {
  static const paper = Color(0xFFFAFAF7);
  static const ink = Color(0xFF122A30);
  static const muted = Color(0xFF647478);
  static const lime = Color(0xFFE3F5AE);
  static const line = Color(0xFFE7E9E3);
}

class StudioHeader extends StatelessWidget {
  const StudioHeader({super.key, this.showAdmin = false});
  final bool showAdmin;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'tokilo.',
          style: TextStyle(
            color: StudioColors.ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
          ),
        ),
      ),
      if (showAdmin && isAdminUser())
        IconButton(
          tooltip: 'Admin workspace',
          onPressed: () => context.go('/admin/dashboard'),
          icon: const Icon(
            Icons.dashboard_outlined,
            color: StudioColors.ink,
            size: 22,
          ),
        ),
      TopStatusActions(
        isAdmin: isAdminUser(),
        iconColor: StudioColors.ink,
        compact: true,
      ),
    ],
  );
}

class StudioSectionTitle extends StatelessWidget {
  const StudioSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: StudioColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
        ),
      ),
      if (action != null && onTap != null)
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: StudioColors.ink),
          child: Text(action!, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

/// A bounded gallery preview, with a purposeful layout for tall app screenshots.
class StudioProjectMedia extends StatefulWidget {
  const StudioProjectMedia({
    super.key,
    required this.title,
    this.url,
    this.category,
    this.height = 214,
    this.animate = true,
  });
  final String title;
  final String? url, category;
  final double height;
  final bool animate;
  @override
  State<StudioProjectMedia> createState() => _StudioProjectMediaState();
}

class _StudioProjectMediaState extends State<StudioProjectMedia> {
  ImageStream? _stream;
  String? _source;
  double? _ratio;
  late final ImageStreamListener _listener = ImageStreamListener((info, sync) {
    final ratio = info.image.width / info.image.height;
    info.dispose();
    if (!mounted || _ratio == ratio) return;
    if (sync) {
      _ratio = ratio;
    } else {
      setState(() => _ratio = ratio);
    }
  }, onError: (_, _) {});

  void _watchImage() {
    if (_source == widget.url) return;
    _stream?.removeListener(_listener);
    _source = widget.url;
    _ratio = null;
    if (_source?.isNotEmpty ?? false) {
      _stream = NetworkImage(
        _source!,
      ).resolve(createLocalImageConfiguration(context));
      _stream!.addListener(_listener);
    } else {
      _stream = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchImage();
  }

  @override
  void didUpdateWidget(covariant StudioProjectMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watchImage();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _openImage() => ImageGalleryViewer.show(
    context,
    images: [widget.url!],
    title: widget.title,
  );

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.url?.isNotEmpty ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Material(
          color: const Color(0xFFEAF0ED),
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _StudioGrid()),
                ),
              ),
              if (hasImage)
                Positioned.fill(
                  child: InkWell(
                    onTap: _openImage,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final portrait = (_ratio ?? .5) < .85;
                          final showCaption =
                              portrait &&
                              MediaQuery.textScalerOf(context).scale(1) < 1.25;
                          final image = Image.network(
                            widget.url!,
                            fit: BoxFit.contain,
                            semanticLabel: 'Project preview: ${widget.title}',
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: StudioColors.muted,
                              ),
                            ),
                          );
                          final framed = Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x24122A30),
                                  blurRadius: 18,
                                  offset: Offset(4, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: image,
                            ),
                          );
                          final media = portrait
                              ? Align(
                                  alignment: Alignment.center,
                                  child: AspectRatio(
                                    aspectRatio: (_ratio ?? .48).clamp(
                                      .32,
                                      .84,
                                    ),
                                    child: framed,
                                  ),
                                )
                              : image;
                          Widget movingMedia(double value) => Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .001)
                              ..rotateY(portrait ? -.12 + value * .05 : 0)
                              ..rotateZ(portrait ? -.045 + value * .025 : 0),
                            child: media,
                          );
                          final visual = widget.animate
                              ? ViewportMotion(
                                  loop: true,
                                  builder: (_, value) => movingMedia(value),
                                )
                              : movingMedia(.5);
                          if (!showCaption) return visual;
                          return Row(
                            children: [
                              SizedBox(
                                width: constraints.maxWidth * .40,
                                child: ExcludeSemantics(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'IN FOCUS',
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: 1.5,
                                          color: StudioColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.category?.trim().isNotEmpty ==
                                                true
                                            ? widget.category!
                                            : 'Digital product',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          height: 1.1,
                                          letterSpacing: -.6,
                                          color: StudioColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        width: 28,
                                        height: 3,
                                        color: StudioColors.ink,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: visual),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 36,
                          color: StudioColors.ink,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Project overview',
                          style: TextStyle(
                            fontSize: 12,
                            color: StudioColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasImage)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton.filledTonal(
                    tooltip: 'Open project image',
                    onPressed: _openImage,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .95),
                      foregroundColor: StudioColors.ink,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E7E1)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StudioGrid oldDelegate) => false;
}
