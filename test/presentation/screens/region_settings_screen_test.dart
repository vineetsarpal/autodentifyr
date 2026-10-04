import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodentifyr/presentation/controllers/region_preference_controller.dart';
import 'package:autodentifyr/presentation/screens/region_settings_screen.dart';
import 'package:autodentifyr/services/region_preference_store.dart';

class TestRegionStore implements RegionPreferenceStore {
  String? countryCode;
  bool failWrite = false;

  @override
  Future<String?> readCountryCode() async => countryCode;

  @override
  Future<void> writeCountryCode(String? value) async {
    if (failWrite) throw StateError('write failed');
    countryCode = value;
  }
}

void main() {
  testWidgets('search, select, and reset region on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestRegionStore();
    final controller = RegionPreferenceController(
      store: store,
      deviceLocale: () => const Locale('en', 'CA'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(home: RegionSettingsScreen(controller: controller)),
    );
    expect(find.text('Canada · CAD'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'INR');
    await tester.pumpAndSettle();
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(store.countryCode, 'IN');
    expect(find.text('India · INR'), findsOneWidget);
    expect(
      find.text('Your selection is saved on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use device region'));
    await tester.pumpAndSettle();
    expect(store.countryCode, isNull);
    expect(find.text('Canada · CAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unresolved region, empty search, and save failure are visible', (
    tester,
  ) async {
    final store = TestRegionStore()..failWrite = true;
    final controller = RegionPreferenceController(
      store: store,
      deviceLocale: () => const Locale('en'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(home: RegionSettingsScreen(controller: controller)),
    );
    expect(find.text('Choose your country'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no-such-country');
    await tester.pumpAndSettle();
    expect(
      find.text('No supported countries match your search.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Canada');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Canada'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your region. Please try again.'),
      findsOneWidget,
    );
    expect(controller.region, isNull);
    store.failWrite = false;
    await tester.tap(find.widgetWithText(ListTile, 'Canada'));
    await tester.pumpAndSettle();
    expect(find.text('Canada · CAD'), findsOneWidget);
    expect(controller.error, isNull);
  });
  testWidgets('large text and keyboard leave settings scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = RegionPreferenceController(
      store: TestRegionStore(),
      deviceLocale: () => const Locale('en', 'CA'),
    );
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: child!,
        ),
        home: RegionSettingsScreen(controller: controller),
      ),
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'INR');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'India'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'India'));
    await tester.pumpAndSettle();
    expect(controller.currencyCode, 'INR');
    expect(tester.takeException(), isNull);
  });
}
