import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('diagram selection returns a canonical component to its parent', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _PickerHarness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-view-front')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('diagram-component-front_bumper')).first,
    );
    await tester.pump();
    expect(find.text('Use Front bumper'), findsOneWidget);

    await tester.tap(find.byKey(const Key('use-component-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Parent: Front bumper'), findsOneWidget);
  });

  testWidgets('list search, Undo, and Use are deterministic and local', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _PickerHarness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('component-search')),
      'tailgate',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('picker-component-tailgate')).first);
    await tester.pump();
    expect(find.text('Use Tailgate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('picker-undo')));
    await tester.pump();
    expect(find.text('Select a component'), findsOneWidget);
    expect(find.byKey(const Key('use-component-selection')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('use-component-selection')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('picker-component-tailgate')).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('use-component-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Parent: Tailgate'), findsOneWidget);
  });
}

class _PickerHarness extends StatefulWidget {
  const _PickerHarness();

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
                    builder: (_) =>
                        VehicleComponentPickerScreen(existingId: _selected),
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
