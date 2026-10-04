import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/presentation/widgets/vehicle_component_diagram.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VehicleComponentGeometry geometry;
  setUpAll(() async {
    geometry = VehicleComponentGeometry.fromJsonString(
      await File(VehicleComponentGeometry.assetPath).readAsString(),
    );
  });

  Widget app({
    VehicleComponentId? selected,
    List<VehicleComponentId> candidates = const [],
    List<VehicleComponentExistingFinding> findings = const [],
    VehicleView view = VehicleView.front,
    VehicleComponentGeometry? replacementGeometry,
    ThemeData? theme,
    bool disableAnimations = false,
    bool accessibleNavigation = false,
    ValueChanged<VehicleComponentExistingFinding>? onFinding,
    ValueChanged<VehicleComponentId>? onSelected,
    ValueChanged<VehicleComponentTapResolution>? onResolution,
    double width = 600,
  }) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: VehicleComponentDiagram(
              geometry: replacementGeometry ?? geometry,
              view: view,
              selectedId: selected,
              candidateIds: candidates,
              existingFindings: findings,
              onExistingFindingSelected: onFinding,
              onSelected: onSelected ?? (_) {},
              onTapResolution: onResolution,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('animation repaints while semantics and badges stay static', (
    tester,
  ) async {
    final findings = [_finding('one', VehicleComponentId.hood)];
    await tester.pumpWidget(
      app(selected: VehicleComponentId.frontBumper, findings: findings),
    );
    await tester.pumpWidget(
      app(selected: VehicleComponentId.hood, findings: findings),
    );
    final selectedFinder = find.byKey(const Key('diagram-component-hood'));
    expect(
      tester.widget<Semantics>(selectedFinder).properties.selected,
      isTrue,
    );
    final semanticWidget = tester.widget(selectedFinder);
    final badgeWidget = tester.widget(
      find.byKey(const Key('existing-finding-badge-hood-one')),
    );
    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('vehicle-component-custom-paint')),
    );
    final start = await _paintPixels(tester);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget(selectedFinder), same(semanticWidget));
      expect(
        tester.widget(find.byKey(const Key('existing-finding-badge-hood-one'))),
        same(badgeWidget),
      );
      expect(
        tester.widget(find.byKey(const Key('vehicle-component-custom-paint'))),
        same(paint),
      );
    }
    final middle = await _paintPixels(tester);
    expect(middle, isNot(start));
    await tester.pump(const Duration(milliseconds: 120));
    expect(await _paintPixels(tester), isNot(middle));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'copied indices detect in-place candidate and finding list changes',
    (tester) async {
      final candidates = [
        VehicleComponentId.hood,
        VehicleComponentId.frontBumper,
        VehicleComponentId.hood,
      ];
      final findings = [
        _finding('one', VehicleComponentId.hood),
        _finding('two', VehicleComponentId.hood, confirmed: true),
      ];
      VehicleComponentExistingFinding? tapped;
      await tester.pumpWidget(
        app(
          candidates: candidates,
          findings: findings,
          onFinding: (value) => tapped = value,
        ),
      );
      final hood = find.byKey(const Key('diagram-component-hood'));
      expect(
        tester.widget<Semantics>(hood).properties.label,
        contains('Possible match 1'),
      );
      expect(
        tester.widget<Semantics>(hood).properties.label,
        contains('2 existing findings, 1 confirmed, 1 proposed'),
      );
      await tester.tap(
        find.byKey(const Key('existing-finding-badge-hood-two')),
      );
      expect(tapped, same(findings[1]));
      candidates.removeAt(0);
      findings.removeAt(0);
      findings[0] = _finding('two', VehicleComponentId.hood);
      await tester.pumpWidget(app(candidates: candidates, findings: findings));
      expect(
        tester.widget<Semantics>(hood).properties.label,
        contains('Possible match 2'),
      );
      expect(
        tester.widget<Semantics>(hood).properties.label,
        contains('1 existing finding, 1 proposed'),
      );
      expect(
        find.byKey(const Key('existing-finding-badge-hood-one')),
        findsNothing,
      );
      expect(find.text('1'), findsOneWidget);
    },
  );

  for (final mode in ['disableAnimations', 'accessibleNavigation']) {
    testWidgets('$mode selects immediately without scheduled animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          selected: VehicleComponentId.frontBumper,
          disableAnimations: mode == 'disableAnimations',
          accessibleNavigation: mode == 'accessibleNavigation',
        ),
      );
      await tester.pumpWidget(
        app(
          selected: VehicleComponentId.hood,
          disableAnimations: mode == 'disableAnimations',
          accessibleNavigation: mode == 'accessibleNavigation',
        ),
      );
      final pixels = await _paintPixels(tester);
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('diagram-component-hood')))
            .properties
            .selected,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(await _paintPixels(tester), pixels);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets(
    'geometry, view, theme and size changes invalidate drawing and semantics',
    (tester) async {
      await tester.pumpWidget(app());
      final before = await _paintPixels(tester);
      await tester.pumpWidget(app(theme: ThemeData.dark(), width: 500));
      expect(await _paintPixels(tester), isNot(before));
      await tester.pumpWidget(app(view: VehicleView.top));
      expect(find.byKey(const Key('diagram-component-roof')), findsOneWidget);
      expect(
        find.byKey(const Key('diagram-component-front_bumper')),
        findsNothing,
      );
      await tester.pumpWidget(app(view: VehicleView.front));
      final originalFront = await _paintPixels(tester);
      final source =
          jsonDecode(
                (await tester.runAsync(
                  () => File(VehicleComponentGeometry.assetPath).readAsString(),
                ))!,
              )
              as Map<String, dynamic>;
      final front = (source['views'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((view) => view['id'] == 'front');
      final bumper =
          (front['occurrences'] as List).first as Map<String, dynamic>;
      bumper['semanticsOrder'] = 2;
      ((front['occurrences'] as List)[1]
              as Map<String, dynamic>)['semanticsOrder'] =
          1;
      final occurrences = front['occurrences'] as List;
      occurrences[0] = occurrences[1];
      occurrences[1] = bumper;
      bumper['visualPath'] = 'M200 440 L800 440 L840 530 L160 530 Z';
      final replacement = VehicleComponentGeometry.fromJsonString(
        jsonEncode(source),
      );
      await tester.pumpWidget(
        app(view: VehicleView.front, replacementGeometry: replacement),
      );
      expect(
        find.byKey(const Key('diagram-component-front_bumper')),
        findsOneWidget,
      );
      expect(await _paintPixels(tester), isNot(originalFront));
      final expected = replacement.view(VehicleView.front).occurrences.toList()
        ..sort((a, b) => a.semanticsOrder.compareTo(b.semanticsOrder));
      final actual = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'diagram-component-',
                  ),
            ),
          )
          .map((widget) => (widget.key! as ValueKey<String>).value);
      expect(
        actual,
        expected.map(
          (value) => 'diagram-component-${value.componentId.wireValue}',
        ),
      );
    },
  );

  testWidgets(
    'pressed feedback and tap resolution keep callbacks and geometry mapping',
    (tester) async {
      VehicleComponentTapResolution? result;
      VehicleComponentId? selected;
      await tester.pumpWidget(
        app(
          onResolution: (value) => result = value,
          onSelected: (id) => selected = id,
        ),
      );
      final paintFinder = find.byKey(
        const Key('vehicle-component-custom-paint'),
      );
      final bounds = tester.getRect(paintFinder);
      final point =
          bounds.topLeft + Offset(bounds.width * .21, bounds.height * .6833);
      final before = await _paintPixels(tester);
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await _paintPixels(tester), isNot(before));
      await gesture.up();
      await tester.pump();
      expect(result, isA<VehicleComponentTapSingle>());
      expect(
        (result! as VehicleComponentTapSingle).occurrence.componentId,
        VehicleComponentId.leftHeadlight,
      );
      expect(selected, isNull);
      expect(await _paintPixels(tester), before);
      await tester.pumpWidget(app(onSelected: (id) => selected = id));
      await tester.tapAt(point);
      expect(selected, VehicleComponentId.leftHeadlight);
    },
  );
}

VehicleComponentExistingFinding _finding(
  String id,
  VehicleComponentId component, {
  bool confirmed = false,
}) => VehicleComponentExistingFinding(
  id: id,
  componentId: component,
  reviewState: confirmed
      ? FindingReviewState.confirmed
      : FindingReviewState.proposed,
  damageType: 'dent',
);

Future<Uint8List> _paintPixels(WidgetTester tester) async {
  final finder = find.byKey(const Key('vehicle-component-custom-paint'));
  final painter = tester.widget<CustomPaint>(finder).painter!;
  final size = tester.getSize(finder);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  try {
    return (await tester.runAsync(() async {
      final raster = await picture.toImage(
        size.width.ceil(),
        size.height.ceil(),
      );
      try {
        return (await raster.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
      } finally {
        raster.dispose();
      }
    }))!;
  } finally {
    picture.dispose();
  }
}
