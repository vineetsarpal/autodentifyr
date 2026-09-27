import 'dart:io';
import 'dart:ui' as ui;

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'suggestion remains separate until the Appraiser explicitly uses it',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VehicleComponentPickerScreen(
            detectorResult: ExactVehicleComponentDetectorResult(
              'picker-suggestion',
              VehicleComponentId.leftFrontDoor,
            ),
          ),
        ),
      );

      expect(find.text('Part: No component selected'), findsOneWidget);
      expect(find.text('Suggested: Left front door'), findsOneWidget);
      expect(find.byKey(const Key('use-component-selection')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('use-component-selection')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('use-suggested-component')));
      await tester.pump();

      expect(find.text('Part: Left front door'), findsOneWidget);
      expect(find.text('Suggested: Left front door'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('use-component-selection')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('existing finding badges are read-only context', (tester) async {
    final geometry = await tester.runAsync(_loadGeometry);
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleComponentPickerScreen(
          geometry: geometry,
          existingFindings: const [
            VehicleComponentExistingFinding(
              id: 'confirmed-roof',
              componentId: VehicleComponentId.roof,
              reviewState: FindingReviewState.confirmed,
              damageType: 'dent',
            ),
            VehicleComponentExistingFinding(
              id: 'proposed-roof',
              componentId: VehicleComponentId.roof,
              reviewState: FindingReviewState.proposed,
              damageType: 'scratch',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final roof = find.byKey(const Key('diagram-component-roof'));
    expect(
      tester.getSemantics(roof).label,
      contains('2 existing findings, 1 confirmed, 1 proposed'),
    );
    await tester.tap(
      find.byKey(const Key('existing-finding-badge-roof-confirmed-roof')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Existing finding'), findsOneWidget);
    expect(find.text('Status: Confirmed'), findsOneWidget);
    expect(find.text('Damage: dent'), findsOneWidget);
    expect(find.text('Part: No component selected'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('existing-finding-badge-roof-proposed-roof')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Status: Proposed'), findsOneWidget);
    expect(find.text('Damage: scratch'), findsOneWidget);
    expect(find.text('Part: No component selected'), findsOneWidget);
  });

  testWidgets('browse sheet orders active choices and searchable catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );

    await tester.tap(find.byKey(const Key('picker-view-front')));
    await tester.pump();
    await _openCatalog(tester);
    expect(find.text('All components'), findsNothing);
    expect(
      find.byKey(const Key('picker-component-left_headlight')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('picker-active-component-left_headlight')),
    );
    await tester.pump();
    expect(find.text('Part: Left headlight'), findsOneWidget);

    await _openCatalog(tester);
    await tester.enterText(
      find.byKey(const Key('component-search')),
      'quarter',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Left rear quarter panel'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('component-browse-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Left rear quarter panel'), findsOneWidget);
    expect(find.text('Right rear quarter panel'), findsOneWidget);
    expect(
      find.byKey(const Key('picker-component-left_rear_quarter_panel')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the component catalog secondary until requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );

    expect(find.byKey(const Key('component-search')), findsNothing);
    expect(find.byKey(const Key('browse-components')), findsOneWidget);

    await _openCatalog(tester);
    expect(find.byKey(const Key('component-search')), findsOneWidget);
  });

  testWidgets(
    'shows observation-backed evidence in initiating order and opens it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VehicleComponentPickerScreen(
            evidence: _pickerEvidence(includeThird: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('picker-evidence-strip')), findsOneWidget);
      expect(find.text('dent'), findsOneWidget);
      expect(find.text('80.0% confidence'), findsOneWidget);
      expect(
        find.byKey(const Key('picker-evidence-thumbnail-bounds-observation-1')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('picker-evidence-carousel')),
      );
      await tester.pumpAndSettle();
      final evidencePosition = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('picker-evidence-carousel')),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      evidencePosition.jumpTo(evidencePosition.viewportDimension);
      await tester.pumpAndSettle();
      expect(find.text('scratch'), findsOneWidget);

      evidencePosition.jumpTo(evidencePosition.viewportDimension * 2);
      await tester.pumpAndSettle();
      expect(find.text('chip'), findsOneWidget);

      evidencePosition.jumpTo(evidencePosition.viewportDimension);
      await tester.pumpAndSettle();
      expect(find.text('scratch'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('open-picker-evidence-observation-2')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Model evidence'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const Key('picker-evidence-bounds-observation-2')),
        findsOneWidget,
      );
    },
  );

  testWidgets('omits evidence when the picker has no observation context', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );

    expect(find.byKey(const Key('picker-evidence-strip')), findsNothing);
  });

  testWidgets('uses a stable fallback for an unavailable evidence image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleComponentPickerScreen(evidence: _pickerEvidence()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('picker-evidence-thumbnail-observation-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping follows the lateral vehicle order in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('picker-view-left')));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('vehicle-view-swipe-area')),
      const Offset(-360, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('picker-view-front')))
          .selected,
      isTrue,
    );

    await tester.fling(
      find.byKey(const Key('vehicle-view-swipe-area')),
      const Offset(360, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('picker-view-left')))
          .selected,
      isTrue,
    );

    await tester.fling(
      find.byKey(const Key('vehicle-view-swipe-area')),
      const Offset(-360, 0),
      1200,
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('vehicle-view-swipe-area')),
      const Offset(-360, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('picker-view-right')))
          .selected,
      isTrue,
    );
  });

  testWidgets('swiping does not leave the top view', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const Key('vehicle-view-swipe-area')),
      const Offset(-360, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('picker-view-top')))
          .selected,
      isTrue,
    );
  });

  testWidgets('golden: empty picker on a narrow phone', (tester) async {
    await _pumpPickerGolden(tester);
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_empty_phone.png'),
    );
  });

  testWidgets('golden: selected picker on a narrow phone', (tester) async {
    await _pumpPickerGolden(tester, selectedId: VehicleComponentId.hood);
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_selected_phone.png'),
    );
  });

  testWidgets('golden: pressed component is visible before selection', (
    tester,
  ) async {
    await _pumpPickerGolden(tester);
    final roof = find.byKey(const Key('diagram-component-roof'));
    final gesture = await tester.startGesture(tester.getCenter(roof));
    await tester.pump();
    expect(find.text('Part: No component selected'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_pressed_phone.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Part: Roof'), findsOneWidget);
  });

  testWidgets('golden: existing findings remain distinct from selection', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      existingFindings: const [
        VehicleComponentExistingFinding(
          id: 'roof-proposed',
          componentId: VehicleComponentId.roof,
          reviewState: FindingReviewState.proposed,
          damageType: 'scratch',
        ),
      ],
    );
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_existing_phone.png'),
    );
  });

  testWidgets('golden: picker keeps initiating model evidence compact', (
    tester,
  ) async {
    await _pumpPickerGolden(tester, evidence: _pickerEvidence());
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_evidence_phone.png'),
    );
  });

  testWidgets('golden: wide picker uses the two-column composition', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      size: const Size(1000, 760),
      selectedId: VehicleComponentId.hood,
    );
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_selected_wide.png'),
    );
  });

  testWidgets('golden: reduced motion renders the selected state directly', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      selectedId: VehicleComponentId.hood,
      disableAnimations: true,
    );
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_reduced_motion.png'),
    );
  });

  testWidgets('golden: exact detector suggestion is spatially marked', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      detectorResult: const ExactVehicleComponentDetectorResult(
        'bonnet-dent',
        VehicleComponentId.hood,
      ),
    );
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile(
        'goldens/vehicle_component_picker_exact_suggestion.png',
      ),
    );
  });

  testWidgets('golden: detector candidates are spatially numbered', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      detectorResult: const CandidateVehicleComponentDetectorResult(
        'headlight-damage',
        [VehicleComponentId.leftHeadlight, VehicleComponentId.rightHeadlight],
      ),
    );
    await tester.tap(find.byKey(const Key('picker-view-front')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('picker-golden-boundary')),
      matchesGoldenFile('goldens/vehicle_component_picker_candidates.png'),
    );
  });

  testWidgets('golden: browse sheet keeps suggestions before catalog choices', (
    tester,
  ) async {
    await _pumpPickerGolden(
      tester,
      detectorResult: const CandidateVehicleComponentDetectorResult(
        'headlight-damage',
        [VehicleComponentId.leftHeadlight, VehicleComponentId.rightHeadlight],
      ),
    );
    await _openCatalog(tester);
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/vehicle_component_picker_browse.png'),
    );
  });

  testWidgets('golden: browse sheet states an empty search result', (
    tester,
  ) async {
    await _pumpPickerGolden(tester);
    await _openCatalog(tester);
    await tester.enterText(find.byKey(const Key('component-search')), 'zzzzz');
    await tester.pump();
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/vehicle_component_picker_search_empty.png'),
    );
  });

  testWidgets('golden: ambiguous panel tap offers spatial previews', (
    tester,
  ) async {
    final geometry = await tester.runAsync(_loadGeometry);
    await tester.pumpWidget(
      MaterialApp(home: VehicleComponentPickerScreen(geometry: geometry)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('picker-view-front')));
    await tester.pumpAndSettle();
    final canvas = tester.getRect(
      find.byKey(const Key('vehicle-component-custom-paint')),
    );
    await tester.tapAt(
      Offset(canvas.left + canvas.width * .3, canvas.top + canvas.height * .15),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/vehicle_component_picker_ambiguity.png'),
    );
  });

  testWidgets('candidate mappings require an Appraiser choice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VehicleComponentPickerScreen(
          detectorResult: CandidateVehicleComponentDetectorResult(
            'headlight-damage',
            [
              VehicleComponentId.leftHeadlight,
              VehicleComponentId.rightHeadlight,
            ],
          ),
        ),
      ),
    );

    expect(find.text('Part: No component selected'), findsOneWidget);
    expect(find.text('Suggested components'), findsNothing);
    await _openCatalog(tester);
    expect(find.text('Suggested components'), findsOneWidget);
    expect(
      find.byKey(const Key('candidate-component-left_headlight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('candidate-component-right_headlight')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('use-component-selection')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const Key('candidate-component-right_headlight')),
    );
    await tester.pump();
    expect(find.text('Part: Right headlight'), findsOneWidget);
  });

  testWidgets('detector highlights remain spatial and clear after preview', (
    tester,
  ) async {
    final geometry = await tester.runAsync(_loadGeometry);
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleComponentPickerScreen(
          geometry: geometry,
          detectorResult: const CandidateVehicleComponentDetectorResult(
            'headlight-damage',
            [
              VehicleComponentId.leftHeadlight,
              VehicleComponentId.rightHeadlight,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('picker-view-front')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('diagram-component-left_headlight')),
          )
          .label,
      contains('Possible match 1'),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('diagram-component-right_headlight')),
          )
          .label,
      contains('Possible match 2'),
    );
    expect(
      find.text('Which highlighted component is affected?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('browse-components')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('candidate-component-button-right_headlight')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Part: Right headlight'), findsOneWidget);
    expect(find.text('Which highlighted component is affected?'), findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('diagram-component-left_headlight')),
          )
          .label,
      isNot(contains('Possible match')),
    );
  });

  testWidgets(
    'exact detector suggestion is not selected until explicitly used',
    (tester) async {
      final geometry = await tester.runAsync(_loadGeometry);
      await tester.pumpWidget(
        MaterialApp(
          home: VehicleComponentPickerScreen(
            geometry: geometry,
            detectorResult: const ExactVehicleComponentDetectorResult(
              'bonnet-dent',
              VehicleComponentId.hood,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hood = find.byKey(const Key('diagram-component-hood'));
      expect(tester.getSemantics(hood).label, contains('Suggested'));
      expect(
        tester.getSemantics(hood).getSemanticsData().flagsCollection.isSelected,
        isNot(ui.Tristate.isTrue),
      );
      expect(
        find.text(
          'Review the highlighted suggestion, then choose Use if it matches.',
        ),
        findsWidgets,
      );

      await tester.tap(find.byKey(const Key('use-suggested-component')));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(hood).label, contains('Selected'));
      expect(tester.getSemantics(hood).label, isNot(contains('Suggested')));
    },
  );

  testWidgets('browse search gives an accessible empty result state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentPickerScreen()),
    );

    await _openCatalog(tester);
    await tester.enterText(find.byKey(const Key('component-search')), 'zzzzz');
    await tester.pump();

    expect(
      find.byKey(const Key('component-search-empty-results')),
      findsOneWidget,
    );
    expect(find.text('No components match that search.'), findsOneWidget);
  });

  testWidgets('unknown mappings start with an empty top view', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VehicleComponentPickerScreen(
          detectorResult: UnknownVehicleComponentDetectorResult('unmapped'),
        ),
      ),
    );

    expect(find.text('Part: No component selected'), findsOneWidget);
    expect(find.byKey(const Key('picker-view-top')), findsOneWidget);
    expect(
      find.byKey(const Key('picker-view-top')).evaluate().single.widget,
      isA<ChoiceChip>(),
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('picker-view-top')))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'renders authored vehicle geometry and resolves an ambiguous tap',
    (tester) async {
      final geometry = await tester.runAsync(_loadGeometry);
      await tester.pumpWidget(
        MaterialApp(home: VehicleComponentPickerScreen(geometry: geometry)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('picker-view-front')));
      await tester.pumpAndSettle();

      final paint = find.byKey(const Key('vehicle-component-custom-paint'));
      expect(paint, findsOneWidget);
      final canvas = tester.getRect(paint);
      await tester.tapAt(
        Offset(
          canvas.left + canvas.width * .3,
          canvas.top + canvas.height * .15,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Choose the affected component'), findsOneWidget);
      expect(find.text('Left front fender'), findsWidgets);
      expect(find.text('Front windscreen'), findsWidgets);
      expect(find.text('Vehicle left, front outer wheel arch'), findsOneWidget);
      expect(find.text('Front centre, upper glass'), findsOneWidget);
      expect(find.text('Browse all components'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('ambiguity-browse-all-components')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Browse vehicle components'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('component-search')),
        'windscreen',
      );
      await tester.pump();
      final windscreen = find.byKey(
        const Key('picker-component-front_windscreen'),
      );
      await tester.scrollUntilVisible(
        windscreen,
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('component-browse-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(windscreen);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Part: Front windscreen'), findsOneWidget);
    },
  );

  testWidgets('miss keeps the selection and offers concise diagram guidance', (
    tester,
  ) async {
    final geometry = await tester.runAsync(_loadGeometry);
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleComponentPickerScreen(
          existingId: VehicleComponentId.hood,
          geometry: geometry,
        ),
      ),
    );
    await tester.pump();
    final paint = find.byKey(const Key('vehicle-component-custom-paint'));
    final canvas = tester.getRect(paint);
    await tester.tapAt(
      Offset(
        canvas.left + canvas.width * .01,
        canvas.top + canvas.height * .01,
      ),
    );
    await tester.pump();

    expect(find.text('Part: Hood'), findsOneWidget);
    expect(
      find.text(
        'Tap a highlighted vehicle component or choose one from the list.',
      ),
      findsOneWidget,
    );
  });
}

Future<VehicleComponentGeometry> _loadGeometry() async =>
    VehicleComponentGeometry.fromJsonString(
      await File(
        'assets/vehicle_components/vehicle_component_geometry.v1.json',
      ).readAsString(),
    );

Future<void> _openCatalog(WidgetTester tester) async {
  final browseButton = find.byKey(const Key('browse-components'));
  await tester.ensureVisible(browseButton);
  await tester.pumpAndSettle();
  await tester.tap(browseButton);
  await tester.pumpAndSettle();
}

Future<void> _pumpPickerGolden(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  VehicleComponentId? selectedId,
  VehicleComponentDetectorResult? detectorResult,
  VehicleComponentPickerEvidence? evidence,
  List<VehicleComponentExistingFinding> existingFindings = const [],
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final geometry = (await tester.runAsync(_loadGeometry))!;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: RepaintBoundary(
          key: const Key('picker-golden-boundary'),
          child: VehicleComponentPickerScreen(
            existingId: selectedId,
            detectorResult: detectorResult,
            evidence: evidence,
            existingFindings: existingFindings,
            geometry: geometry,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

VehicleComponentPickerEvidence _pickerEvidence({bool includeThird = false}) {
  final acceptedAt = DateTime(2026, 1, 1);
  return VehicleComponentPickerEvidence(
    captures: [
      Capture(
        id: 'capture-1',
        source: CaptureSource.camera,
        localPath: '/missing/capture-1.jpg',
        acceptedByProfileId: 'appraiser-1',
        acceptedAt: acceptedAt,
      ),
      Capture(
        id: 'capture-2',
        source: CaptureSource.import,
        localPath: '/missing/capture-2.jpg',
        acceptedByProfileId: 'appraiser-1',
        acceptedAt: acceptedAt,
      ),
      if (includeThird)
        Capture(
          id: 'capture-3',
          source: CaptureSource.camera,
          localPath: '/missing/capture-3.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: acceptedAt,
        ),
    ],
    observations: [
      const DamageObservation(
        id: 'observation-2',
        captureId: 'capture-2',
        rawClass: 'scratch',
        confidence: .61,
        bounds: ObservationBounds(left: .2, top: .2, width: .4, height: .3),
        modelIdentifier: 'test-model',
      ),
      if (includeThird)
        const DamageObservation(
          id: 'observation-3',
          captureId: 'capture-3',
          rawClass: 'chip',
          confidence: .55,
          bounds: ObservationBounds(left: .3, top: .25, width: .2, height: .2),
          modelIdentifier: 'test-model',
        ),
      const DamageObservation(
        id: 'observation-1',
        captureId: 'capture-1',
        rawClass: 'dent',
        confidence: .8,
        bounds: ObservationBounds(left: .1, top: .2, width: .3, height: .4),
        modelIdentifier: 'test-model',
      ),
    ],
    initiatingObservationId: 'observation-1',
  );
}
