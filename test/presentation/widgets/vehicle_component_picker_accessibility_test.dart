import 'dart:io';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleComponentPicker accessibility gate', () {
    testWidgets('meets Android target, label, and contrast guidelines', (
      tester,
    ) async {
      await _pumpPicker(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('exposes names, actions, selected state, and view ordering', (
      tester,
    ) async {
      await _pumpPicker(tester);

      final frontBumper = find
          .byKey(const Key('picker-component-front_bumper'))
          .first;
      expect(find.bySemanticsLabel('Front bumper'), findsWidgets);
      expect(find.semantics.byAction(SemanticsAction.tap), findsWidgets);

      await tester.tap(frontBumper);
      await tester.pump();
      expect(find.text('Part: Front bumper'), findsOneWidget);
      final selectedNodes = find.semantics.byFlag(SemanticsFlag.isSelected);
      expect(
        selectedNodes.evaluate().any(
          (node) => node.getSemanticsData().label.contains('Front bumper'),
        ),
        isTrue,
      );

      final viewChooser = tester.getSemantics(
        find.bySemanticsLabel('Vehicle view'),
      );
      expect(viewChooser.label, 'Vehicle view');
      expect(
        tester.getSemantics(find.byKey(const Key('picker-view-front'))).label,
        contains('Front'),
      );

      await tester.tap(find.byKey(const Key('picker-view-left')));
      await tester.pump();
      expect(find.bySemanticsLabel('Left vehicle diagram'), findsOneWidget);
      expect(find.text('Left mirror'), findsWidgets);
    });

    testWidgets('announces a detector suggestion and supports list selection', (
      tester,
    ) async {
      await _pumpPicker(tester, suggestedId: VehicleComponentId.hood);

      expect(find.text('Suggested: Hood'), findsOneWidget);
      final suggested = find.byKey(const Key('use-suggested-component'));
      expect(tester.getSemantics(suggested).label, contains('Use'));
      await tester.tap(suggested);
      await tester.pump();

      final selectedNodes = find.semantics.byFlag(SemanticsFlag.isSelected);
      expect(
        selectedNodes.evaluate().any(
          (node) => node.getSemanticsData().label.contains('Hood'),
        ),
        isTrue,
      );
      expect(find.text('Part: Hood'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('component-search')),
        'tailgate',
      );
      await tester.pump();
      expect(find.text('Tailgate'), findsWidgets);
    });

    testWidgets('supports keyboard focus traversal and large text at 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final geometry = (await tester.runAsync(_loadGeometry))!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: VehicleComponentPickerScreen(geometry: geometry),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final search = find.byKey(const Key('component-search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preserves local selection across a metrics rebuild', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpPicker(tester);
      await tester.tap(find.byKey(const Key('picker-view-front')));
      await tester.pump();
      final hood = find.byKey(const Key('diagram-component-hood'));
      await tester.ensureVisible(hood);
      await tester.tap(hood);
      await tester.pump();

      tester.view.physicalSize = const Size(800, 400);
      tester.binding.handleMetricsChanged();
      await tester.pump();
      expect(find.text('Part: Hood'), findsOneWidget);
      expect(find.text('Use Hood'), findsOneWidget);
    });

    testWidgets('Cancel and system Back discard local changes; Use commits', (
      tester,
    ) async {
      final geometry = (await tester.runAsync(_loadGeometry))!;
      await tester.pumpWidget(
        MaterialApp(home: _PickerHarness(geometry: geometry)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();
      await _selectHoodFromDiagram(tester);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Parent: none'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();
      await _selectHoodFromDiagram(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Parent: none'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();
      await _selectHoodFromDiagram(tester);
      await tester.tap(find.byKey(const Key('use-component-selection')));
      await tester.pumpAndSettle();
      expect(find.text('Parent: Hood'), findsOneWidget);
    });
  });
}

Future<void> _selectHoodFromDiagram(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('picker-view-front')));
  await tester.pump();
  final hood = find.byKey(const Key('diagram-component-hood'));
  await tester.ensureVisible(hood);
  await tester.tap(hood);
  await tester.pump();
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  VehicleComponentId? existingId,
  VehicleComponentId? suggestedId,
}) async {
  final geometry = (await tester.runAsync(_loadGeometry))!;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: VehicleComponentPickerScreen(
        existingId: existingId,
        detectorResult: suggestedId == null
            ? null
            : ExactVehicleComponentDetectorResult(
                'picker-suggestion',
                suggestedId,
              ),
        geometry: geometry,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<VehicleComponentGeometry> _loadGeometry() async =>
    VehicleComponentGeometry.fromJsonString(
      await File(
        'assets/vehicle_components/vehicle_component_geometry.v1.json',
      ).readAsString(),
    );

class _PickerHarness extends StatefulWidget {
  const _PickerHarness({required this.geometry});

  final VehicleComponentGeometry geometry;

  @override
  State<_PickerHarness> createState() => _PickerHarnessState();
}

class _PickerHarnessState extends State<_PickerHarness> {
  VehicleComponentId? _selected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(
          _selected == null
              ? 'Parent: none'
              : 'Parent: ${VehicleComponentCatalog.byId(_selected!).label}',
        ),
        ElevatedButton(
          key: const Key('open-picker'),
          onPressed: () async {
            final selected = await Navigator.of(context)
                .push<VehicleComponentId>(
                  MaterialPageRoute(
                    builder: (_) => VehicleComponentPickerScreen(
                      existingId: _selected,
                      geometry: widget.geometry,
                    ),
                  ),
                );
            if (selected != null && mounted) {
              setState(() => _selected = selected);
            }
          },
          child: const Text('Open picker'),
        ),
      ],
    ),
  );
}
