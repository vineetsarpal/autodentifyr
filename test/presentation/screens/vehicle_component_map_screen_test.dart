import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/models/vehicle_finding_map_item.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_map_screen.dart';
import 'package:autodentifyr/presentation/widgets/vehicle_findings_map_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'single top-view selector previews a component before explicit Use',
    (tester) async {
      VehicleComponentId? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  accepted = await Navigator.of(context)
                      .push<VehicleComponentId>(
                        MaterialPageRoute(
                          builder: (_) => const VehicleComponentMapScreen(
                            items: [
                              VehicleFindingMapItem(
                                findingId: 'finding-1',
                                componentId: VehicleComponentId.hood,
                                damageType: 'Dent',
                                state: VehicleFindingMapState.proposed,
                                confidence: .8,
                                evidenceCount: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                },
                child: const Text('Open map'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();

      for (final label in ['FRONT', 'REAR', 'LEFT', 'RIGHT']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Browse components'), findsOneWidget);
      expect(find.text('Reset view'), findsOneWidget);

      final semantics = tester.ensureSemantics();
      final canvas = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is VehicleFindingsMapGeometry,
      );
      final labels = <String>{};
      bool collectLabels(SemanticsNode node) {
        final label = node.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        node.visitChildren(collectLabels);
        return true;
      }

      collectLabels(tester.getSemantics(canvas));
      for (final component in VehicleComponentCatalog.all) {
        expect(
          labels.any(
            (label) => label.startsWith('${component.label} vehicle component'),
          ),
          isTrue,
          reason: '${component.label} needs a semantic map region.',
        );
      }

      final canvasSize = tester.getSize(canvas);
      final hood = vehicleMapRegions(
        VehicleView.top,
      ).firstWhere((region) => region.componentId == VehicleComponentId.hood);
      final transform = VehicleMapTransform(
        VehicleMapGeometry.forView(VehicleView.top).size,
        canvasSize,
      );
      await tester.tapAt(
        tester.getTopLeft(canvas) + transform.local(hood.anchor),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hood'), findsWidgets);
      expect(find.text('Dent'), findsOneWidget);
      expect(find.textContaining('80% confidence'), findsOneWidget);
      expect(find.text('Use component anyway'), findsOneWidget);

      await tester.tap(find.text('Use component anyway'));
      await tester.pumpAndSettle();
      expect(accepted, VehicleComponentId.hood);
      semantics.dispose();
    },
  );

  testWidgets('Browse components selects locally and Cancel returns nothing', (
    tester,
  ) async {
    VehicleComponentId? accepted = VehicleComponentId.hood;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                accepted = await Navigator.of(context).push<VehicleComponentId>(
                  MaterialPageRoute(
                    builder: (_) => const VehicleComponentMapScreen(items: []),
                  ),
                );
              },
              child: const Text('Open map'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse components'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('top-map-component-search')),
      'running board',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('top-map-component-left_running_board')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Left running board'), findsWidgets);

    await tester.tap(find.byKey(const Key('cancel-component-map')));
    await tester.pumpAndSettle();
    expect(accepted, isNull);
  });

  testWidgets('overlapping rear closure asks between trunk lid and tailgate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VehicleComponentMapScreen(items: [])),
    );
    await tester.pumpAndSettle();

    final canvas = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VehicleFindingsMapGeometry,
    );
    final tailgate = vehicleMapRegions(
      VehicleView.top,
    ).firstWhere((region) => region.componentId == VehicleComponentId.tailgate);
    final transform = VehicleMapTransform(
      VehicleMapGeometry.forView(VehicleView.top).size,
      tester.getSize(canvas),
    );
    await tester.tapAt(
      tester.getTopLeft(canvas) + transform.local(tailgate.anchor),
    );
    await tester.pumpAndSettle();

    expect(find.text('Which component?'), findsOneWidget);
    expect(find.text('Trunk lid'), findsOneWidget);
    expect(find.text('Tailgate'), findsOneWidget);
  });

  testWidgets(
    'full-screen map remains usable at large text on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const VehicleComponentMapScreen(
            items: [],
            initialComponent: VehicleComponentId.hood,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Use Hood'), findsOneWidget);
      expect(find.byTooltip('Browse components'), findsOneWidget);
    },
  );

  testWidgets('resting component drawer leaves the full vehicle map visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: VehicleComponentMapScreen(
          items: [],
          initialComponent: VehicleComponentId.hood,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapFrame = find.byKey(const Key('vehicle-map-frame'));
    final selectionSheet = find.byKey(const Key('component-selection-sheet'));
    expect(tester.getSize(mapFrame).height, greaterThan(300));
    expect(
      tester.getBottomLeft(mapFrame).dy,
      lessThanOrEqualTo(tester.getTopLeft(selectionSheet).dy),
    );
    expect(find.text('REAR'), findsOneWidget);
    expect(find.text('Use Hood'), findsOneWidget);
  });
}
