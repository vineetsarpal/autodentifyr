import 'package:autodentifyr/presentation/widgets/photo_detections_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens only on tap, shows numbered findings, and can reopen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhotoDetectionsButton(
            detections: [
              (name: 'Door outer dent', confidence: .88, estimate: 500),
              (name: 'Door outer dent', confidence: .89, estimate: 500),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Detected damages (2)'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await tester.tap(find.byIcon(Icons.warning_amber_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Detected damages (2)'), findsOneWidget);
    expect(find.text('Door outer dent'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('88% confidence'), findsOneWidget);
    expect(find.text('89% confidence'), findsOneWidget);
    expect(find.text('\$500'), findsNWidgets(2));
    expect(find.text('Preliminary estimates'), findsNothing);
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    await tester.tap(find.byTooltip('Close detected damages'));
    await tester.pumpAndSettle();
    expect(find.text('Detected damages (2)'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(PhotoDetectionsButton),
        matching: find.text('2'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detected damages (2)'), findsOneWidget);
  });

  testWidgets('zero detections can still open an honest empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PhotoDetectionsButton(detections: [])),
      ),
    );
    await tester.tap(find.text('Detections'));
    await tester.pumpAndSettle();
    expect(
      find.text('No damage detected. This does not rule out damage.'),
      findsOneWidget,
    );
  });

  testWidgets('results scroll and handle missing confidence or price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoDetectionsButton(
            detections: List.generate(
              20,
              (index) => (
                name: 'Damage ${index + 1}',
                confidence: null,
                estimate: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Detections'));
    await tester.pumpAndSettle();
    expect(find.text('Confidence unavailable'), findsWidgets);
    expect(find.text('Not priced'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Damage 20'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Damage 20').hitTestable(), findsOneWidget);
  });
}
