import 'package:autodentifyr/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick detection precedes the beta assessment workspace', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    final quickDetection = find.text('QUICK DETECTION');
    final workspace = find.text('Assessment Workspace');
    expect(
      tester.getTopLeft(quickDetection).dy,
      lessThan(tester.getTopLeft(workspace).dy),
    );
    expect(
      tester.getTopLeft(find.text('Live Detection')).dy,
      lessThan(tester.getTopLeft(workspace).dy),
    );

    final workspaceCard = find.ancestor(
      of: workspace,
      matching: find.byType(InkWell),
    );
    final liveCard = find.ancestor(
      of: find.text('Live Detection'),
      matching: find.byType(InkWell),
    );
    expect(find.text('BETA'), findsOneWidget);
    expect(
      find.descendant(of: workspaceCard, matching: find.text('BETA')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: liveCard, matching: find.text('BETA')),
      findsNothing,
    );
  });
}
