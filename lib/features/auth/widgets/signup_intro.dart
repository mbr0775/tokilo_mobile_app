import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/tech_scene.dart';

class SignupIntro extends StatelessWidget {
  const SignupIntro({super.key, required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.of(context).accessibleNavigation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOUR NEXT CHAPTER',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A space for your\nnext big idea.',
          style: TextStyle(
            fontSize: 35,
            height: 1.08,
            letterSpacing: -1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Create your account. Connect with Tokilo and bring your digital projects together.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE2F1EF), Color(0xFFF0F5DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: AnimatedBuilder(
              animation: scrollController,
              child: const RepaintBoundary(child: TechScene(height: 200)),
              builder: (context, child) {
                final offset = reduced || !scrollController.hasClients
                    ? 0.0
                    : scrollController.offset.clamp(0.0, 450.0);
                return Transform(
                  key: const ValueKey('signup-parallax'),
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .001)
                    ..translateByDouble(0, offset * .08, 0, 1)
                    ..rotateY(offset * .00025),
                  child: child,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
