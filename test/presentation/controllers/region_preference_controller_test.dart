import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autodentifyr/presentation/controllers/region_preference_controller.dart';
import 'package:autodentifyr/services/region_preference_store.dart';

class MemoryRegionStore implements RegionPreferenceStore {
  String? countryCode;
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? pendingWrite;

  @override
  Future<String?> readCountryCode() async {
    if (failRead) throw StateError('read failed');
    return countryCode;
  }

  @override
  Future<void> writeCountryCode(String? value) async {
    if (failWrite) throw StateError('write failed');
    await pendingWrite?.future;
    countryCode = value;
  }
}

void main() {
  late MemoryRegionStore store;
  late RegionPreferenceController controller;
  var locale = const Locale('en', 'CA');

  setUp(() {
    store = MemoryRegionStore();
    locale = const Locale('en', 'CA');
    controller = RegionPreferenceController(
      store: store,
      deviceLocale: () => locale,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'uses country rather than language and does not persist a guess',
    () async {
      await controller.load();
      expect(controller.region?.countryCode, 'CA');
      expect(controller.currencyCode, 'CAD');
      expect(controller.source, RegionPreferenceSource.deviceRegion);
      expect(store.countryCode, isNull);
    },
  );

  test('missing and unsupported country stay unresolved', () async {
    for (final value in [const Locale('en'), const Locale('en', 'ZZ')]) {
      locale = value;
      await controller.load();
      expect(controller.region, isNull);
      expect(controller.currencyCode, isNull);
      expect(controller.error, isNull);
    }
  });

  test('manual choice survives reload and device region changes', () async {
    await controller.load();
    expect(await controller.selectCountry('in'), isTrue);
    locale = const Locale('en', 'US');
    await controller.load();
    expect(store.countryCode, 'IN');
    expect(controller.currencyCode, 'INR');
    expect(controller.source, RegionPreferenceSource.manual);
    expect(await controller.selectCountry(null), isTrue);
    expect(store.countryCode, isNull);
    expect(controller.currencyCode, 'USD');
    expect(controller.source, RegionPreferenceSource.deviceRegion);
  });

  test('failed save preserves previous region and supports retry', () async {
    await controller.load();
    store.failWrite = true;
    expect(await controller.selectCountry('JP'), isFalse);
    expect(controller.currencyCode, 'CAD');
    expect(controller.error, contains('save'));
    expect(controller.isBusy, isFalse);
    store.failWrite = false;
    expect(await controller.selectCountry('JP'), isTrue);
    expect(controller.currencyCode, 'JPY');
    expect(controller.error, isNull);
  });

  test('failed read does not overwrite a manual choice', () async {
    await controller.selectCountry('GB');
    store.failRead = true;
    await controller.load();
    expect(controller.currencyCode, 'GBP');
    expect(controller.source, RegionPreferenceSource.manual);
    expect(controller.error, contains('load'));
  });

  test(
    'invalid saved country asks for correction instead of guessing',
    () async {
      store.countryCode = 'ZZ';
      await controller.load();
      expect(controller.region, isNull);
      expect(controller.error, isNotNull);
      expect(await controller.selectCountry('CA'), isTrue);
      expect(controller.error, isNull);
      expect(await controller.selectCountry('ZZ'), isFalse);
      expect(controller.currencyCode, 'CAD');
    },
  );

  test(
    'overlapping writes are rejected and disposal during save is safe',
    () async {
      store.pendingWrite = Completer<void>();
      final saving = controller.selectCountry('GB');
      expect(controller.isBusy, isTrue);
      expect(await controller.selectCountry('US'), isFalse);
      // Use a separate controller to keep the tearDown ownership simple.
      final disposable = RegionPreferenceController(
        store: MemoryRegionStore()..pendingWrite = store.pendingWrite,
        deviceLocale: () => locale,
      );
      final disposableSave = disposable.selectCountry('IN');
      disposable.dispose();
      store.pendingWrite!.complete();
      expect(await saving, isTrue);
      expect(await disposableSave, isTrue);
      expect(controller.currencyCode, 'GBP');
    },
  );
}
