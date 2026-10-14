import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokilo/features/auth/widgets/signup_consent.dart';
import 'package:tokilo/features/auth/widgets/signup_intro.dart';

void main() {
  for (final width in [320.0, 600.0]) {
    testWidgets('consent stays aligned with large text at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var accepted = false;
      var termsOpened = 0;
      var privacyOpened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: StatefulBuilder(
                builder: (context, update) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: SignupConsent(
                    accepted: accepted,
                    onChanged: (value) => update(() => accepted = value),
                    onOpenTerms: () => termsOpened++,
                    onOpenPrivacy: () => privacyOpened++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final checkboxRect = tester.getRect(find.byType(Checkbox));
      final labelRect = tester.getRect(
        find.text('I accept the Privacy Policy and Terms & Conditions.'),
      );
      expect(checkboxRect.height, greaterThanOrEqualTo(48));
      expect((checkboxRect.center.dy - labelRect.center.dy).abs(), lessThan(1));
      await tester.tap(find.text('Terms & Conditions'));
      await tester.tap(find.text('Privacy Policy'));
      expect(termsOpened, 1);
      expect(privacyOpened, 1);
      expect(accepted, isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(accepted, isTrue);
      await tester.tap(
        find.text('I accept the Privacy Policy and Terms & Conditions.'),
      );
      await tester.pump();
      expect(accepted, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'scroll parallax replays and respects reduced motion: $reduced',
      (tester) async {
        final controller = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: const Size(800, 600),
                  disableAnimations: reduced,
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      SignupIntro(scrollController: controller),
                      const SizedBox(height: 1500),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        Matrix4 transform() => tester
            .widget<Transform>(find.byKey(const ValueKey('signup-parallax')))
            .transform;
        final initial = transform().clone();
        controller.jumpTo(180);
        await tester.pump();
        final moved = transform().clone();
        expect(moved == initial, reduced);
        controller.jumpTo(0);
        await tester.pump();
        expect(transform(), initial);
        controller.jumpTo(180);
        await tester.pump();
        expect(transform(), moved);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
}
