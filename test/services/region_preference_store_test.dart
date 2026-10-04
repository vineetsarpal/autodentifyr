import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:autodentifyr/services/region_preference_store.dart';

void main() {
  late Directory directory;
  late File file;
  late FileRegionPreferenceStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('region-preference-test');
    file = File('${directory.path}/settings/region.json');
    store = FileRegionPreferenceStore(resolveFile: () async => file);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('persists a manual selection across instances and clears it', () async {
    expect(await store.readCountryCode(), isNull);
    await store.writeCountryCode('CA');
    final reopened = FileRegionPreferenceStore(resolveFile: () async => file);
    expect(await reopened.readCountryCode(), 'CA');
    await reopened.writeCountryCode('IN');
    expect(await store.readCountryCode(), 'IN');
    expect(await File('${file.path}.tmp').exists(), isFalse);
    await reopened.writeCountryCode(null);
    expect(await store.readCountryCode(), isNull);
    await reopened.writeCountryCode(null);
  });

  test(
    'reports malformed and unknown schema instead of replacing it',
    () async {
      await file.parent.create(recursive: true);
      for (final contents in [
        'broken json',
        '[]',
        '{"version":2,"countryCode":"CA"}',
        '{"version":1,"countryCode":7}',
      ]) {
        await file.writeAsString(contents);
        await expectLater(store.readCountryCode(), throwsFormatException);
        expect(await file.readAsString(), contents);
      }
      await store.writeCountryCode('GB');
      expect(await store.readCountryCode(), 'GB');
    },
  );
}
