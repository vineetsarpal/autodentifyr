import 'dart:io';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
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

  testWidgets(
    'active-view and all-components search select canonical identities',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VehicleComponentPickerScreen()),
      );

      await tester.tap(find.byKey(const Key('picker-view-front')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('picker-active-component-left_headlight')),
      );
      await tester.pump();
      expect(find.text('Part: Left headlight'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('component-search')),
        'quarter',
      );
      await tester.pump();
      expect(find.text('Left rear quarter panel'), findsOneWidget);
      expect(find.text('Right rear quarter panel'), findsOneWidget);
      expect(
        find.byKey(const Key('picker-component-left_rear_quarter_panel')),
        findsOneWidget,
      );
    },
  );

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
    expect(
      find.text('Choose one of these suggested components'),
      findsOneWidget,
    );
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
      await tester.pump();

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
      expect(find.text('Browse all components'), findsOneWidget);
      final windscreen = find.byKey(
        const Key('ambiguity-component-front_windscreen'),
      );
      await tester.ensureVisible(windscreen);
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
