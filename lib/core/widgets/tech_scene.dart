import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'tokilo_motion.dart';

/// A native, decorative product illustration. No network or video assets.
class TechScene extends StatelessWidget {
  const TechScene({super.key, this.height = 210});
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: ViewportMotion(
        loop: true,
        builder: (context, progress) {
          final wave = math.sin(progress * math.pi * 2);
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _OrbitPainter(progress)),
                  ),
                  Positioned(
                    left: width * .13,
                    top: 30 + wave * 6,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .001)
                        ..rotateY(-.28 + wave * .05)
                        ..rotateZ(-.06),
                      child: _Panel(
                        width: width * .53,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                _Dot(),
                                SizedBox(width: 4),
                                _Dot(),
                                SizedBox(width: 4),
                                _Dot(),
                                Spacer(),
                                Icon(
                                  Icons.code_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.hub_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _Line(width: 85),
                            SizedBox(height: 6),
                            _Line(width: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: width * .12,
                    top: 65 - wave * 8,
                    child: Transform.rotate(
                      angle: .09 + wave * .025,
                      child: _Panel(
                        width: 72,
                        child: const Column(
                          children: [
                            SizedBox(width: 18, child: _Line(width: 18)),
                            SizedBox(height: 16),
                            Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.primary,
                              size: 27,
                            ),
                            SizedBox(height: 20),
                            _Line(width: 34),
                            SizedBox(height: 6),
                            _Line(width: 26),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .2,
                    bottom: 12 - wave * 4,
                    child: const _Chip(icon: Icons.language_rounded),
                  ),
                  Positioned(
                    right: width * .15,
                    top: 15 + wave * 4,
                    child: const _Chip(icon: Icons.memory_rounded),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFCBDDDF)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .12),
          blurRadius: 20,
          offset: const Offset(4, 12),
        ),
      ],
    ),
    child: child,
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 5,
    decoration: BoxDecoration(
      color: const Color(0xFFDBE8E9),
      borderRadius: BorderRadius.circular(5),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: const BoxDecoration(
      color: Color(0xFFBACFD1),
      shape: BoxShape.circle,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFFDDF1EF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Icon(icon, color: AppColors.primary, size: 21),
  );
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.35);
    final oval = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .9,
      height: size.height * .55,
    );
    canvas.drawOval(oval, paint);
    final angle = progress * math.pi * 2;
    canvas.drawCircle(
      Offset(
        math.cos(angle) * oval.width / 2,
        math.sin(angle) * oval.height / 2,
      ),
      4,
      Paint()..color = AppColors.primary,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
