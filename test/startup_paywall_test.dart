import 'package:esign_doc_pro/startup_paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in <Size>[const Size(320, 640), const Size(390, 844)]) {
    testWidgets('launch paywall fits $size and allows drafts', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var continued = false;
      await tester.pumpWidget(MaterialApp(
        home: StartupPaywallScreen(
          onContinue: () => continued = true,
        ),
      ));
      await tester.pump();
      expect(find.text('Make every document\nready to go.'), findsOneWidget);
      expect(find.text('Continue with drafts'), findsNothing);
      expect(find.byTooltip('Close paywall'), findsOneWidget);
      await tester.tap(find.byTooltip('Close paywall'));
      expect(continued, isTrue);
    });
  }
}
