import 'package:esign_doc_pro/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding visual states', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: OnboardingScreen(onDone: () {}),
    ));
    await tester.pump();
    await expectLater(find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/onboarding_scan.png'));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/onboarding_sign.png'));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/onboarding_export.png'));
  });
}
