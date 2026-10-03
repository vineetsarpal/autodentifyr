import 'dart:async';
import 'dart:io';

import 'package:autodentifyr/services/model_path_cache.dart';
import 'package:flutter_test/flutter_test.dart';

const androidKey = (platform: 'android', modelName: 'best', task: 'detect');
const iosKey = (platform: 'ios', modelName: 'best', task: 'detect');

void main() {
  group('Shared model path resolution', () {
    late ModelPathCache cache;
    late Directory temporary;

    setUp(() async {
      cache = ModelPathCache();
      temporary = await Directory.systemTemp.createTemp('model_path_cache_');
    });
    tearDown(() => temporary.delete(recursive: true));

    test(
      'reuses a successful path and reloads when the file is removed',
      () async {
        final model = await File(
          '${temporary.path}/best.tflite',
        ).writeAsString('model');
        var loads = 0;
        Future<String?> resolve() => cache.resolve(
          key: androidKey,
          load: (_, _) async {
            loads++;
            await model.writeAsString('model');
            return model.path;
          },
        );

        expect(await resolve(), model.path);
        expect(await resolve(), model.path);
        expect(loads, 1);
        await model.delete();
        expect(await resolve(), model.path);
        expect(loads, 2);
      },
    );

    test(
      'coalesces loads and replays status and progress to late subscribers',
      () async {
        final done = Completer<String?>();
        final firstStatuses = <String>[];
        final secondStatuses = <String>[];
        final firstProgress = <double>[];
        final secondProgress = <double>[];
        late void Function(String) status;
        late void Function(double) progress;
        var loads = 0;
        final first = cache.resolve(
          key: androidKey,
          onStatus: firstStatuses.add,
          onProgress: firstProgress.add,
          load: (notifyStatus, notifyProgress) {
            loads++;
            status = notifyStatus;
            progress = notifyProgress;
            status('Downloading best model...');
            progress(.25);
            return done.future;
          },
        );
        final second = cache.resolve(
          key: androidKey,
          onStatus: secondStatuses.add,
          onProgress: secondProgress.add,
          load: (_, _) async => throw StateError('duplicate load'),
        );
        status('Extracting model...');
        progress(1);
        done.complete('/resolved/model');
        expect(await Future.wait([first, second]), [
          '/resolved/model',
          '/resolved/model',
        ]);
        expect(loads, 1);
        expect(secondStatuses, firstStatuses);
        expect(secondProgress, firstProgress);
        expect(secondProgress, [.25, 1]);
      },
    );

    test(
      'completed subscribers do not receive subsequent reload updates',
      () async {
        final statuses = <String>[];
        await cache.resolve(
          key: androidKey,
          onStatus: statuses.add,
          load: (status, _) async {
            status('First attempt');
            return null;
          },
        );
        await cache.resolve(
          key: androidKey,
          load: (status, _) async {
            status('Retry');
            return null;
          },
        );
        expect(statuses, ['First attempt']);
      },
    );

    test('null and error results permit retries for every waiter', () async {
      final failed = Completer<String?>();
      var loads = 0;
      Future<String?> resolve() => cache.resolve(
        key: androidKey,
        load: (_, _) {
          loads++;
          return failed.future;
        },
      );
      final first = expectLater(resolve(), throwsStateError);
      final second = expectLater(resolve(), throwsStateError);
      failed.completeError(StateError('unavailable'));
      await Future.wait([first, second]);
      expect(loads, 1);
      expect(
        await cache.resolve(key: androidKey, load: (_, _) async => null),
        isNull,
      );
      expect(
        await cache.resolve(key: androidKey, load: (_, _) async => '/retry'),
        '/retry',
      );
    });

    test(
      'platform, model name and task each have independent entries',
      () async {
        final keys = [
          androidKey,
          iosKey,
          (platform: 'android', modelName: 'another', task: 'detect'),
          (platform: 'android', modelName: 'best', task: 'segment'),
        ];
        final waits = <Completer<String?>>[];
        final results = <Future<String?>>[];
        for (final key in keys) {
          final wait = Completer<String?>();
          waits.add(wait);
          results.add(cache.resolve(key: key, load: (_, _) => wait.future));
        }
        for (var i = 0; i < waits.length; i++) {
          waits[i].complete('/model_$i');
        }
        expect(await Future.wait(results), [
          '/model_0',
          '/model_1',
          '/model_2',
          '/model_3',
        ]);
      },
    );

    test(
      'revalidates both the iOS package directory and its Manifest',
      () async {
        final package = Directory('${temporary.path}/best.mlpackage');
        var loads = 0;
        Future<String?> resolve() => cache.resolve(
          key: iosKey,
          load: (_, _) async {
            loads++;
            await package.create();
            await File('${package.path}/Manifest.json').writeAsString('{}');
            return package.path;
          },
        );
        expect(await resolve(), package.path);
        expect(await resolve(), package.path);
        expect(loads, 1);
        await File('${package.path}/Manifest.json').delete();
        expect(await resolve(), package.path);
        expect(loads, 2);
        await package.delete(recursive: true);
        expect(await resolve(), package.path);
        expect(loads, 3);
      },
    );

    test(
      'retains an iOS bundled model identifier without a disk path',
      () async {
        expect(
          await cache.resolve(key: iosKey, load: (_, _) async => 'best'),
          'best',
        );
        expect(
          await cache.resolve(
            key: iosKey,
            load: (_, _) async => throw StateError('bundle resolved again'),
          ),
          'best',
        );
      },
    );
  });
}
