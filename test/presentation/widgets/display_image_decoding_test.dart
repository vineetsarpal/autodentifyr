import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/bloc/auth/auth_bloc.dart';
import 'package:autodentifyr/presentation/screens/home_screen.dart';
import 'package:autodentifyr/presentation/screens/login_screen.dart';
import 'package:autodentifyr/presentation/widgets/assessment_evidence_selector.dart';
import 'package:autodentifyr/presentation/widgets/control_button.dart';
import 'package:autodentifyr/presentation/widgets/display_sized_asset_image.dart';
import 'package:autodentifyr/presentation/widgets/model_loading_overlay.dart';
import 'package:autodentifyr/presentation/widgets/observation_evidence.dart';
import 'package:autodentifyr/presentation/widgets/thumbnail_file_image.dart';
import 'package:autodentifyr/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, File> fixtures;
  final cache = PaintingBinding.instance.imageCache;
  setUp(() async {
    cache.clear();
    cache.clearLiveImages();
    directory = await Directory.systemTemp.createTemp('display_decode_');
    fixtures = {};
    for (final fixture in [
      (name: 'wide', width: 1024, height: 256),
      (name: 'tall', width: 256, height: 1024),
      (name: 'square', width: 512, height: 512),
      (name: 'small', width: 40, height: 20),
    ]) {
      final photo = image.Image(width: fixture.width, height: fixture.height);
      image.fill(photo, color: image.ColorRgb8(20, 100, 180));
      fixtures[fixture.name] = await File(
        '${directory.path}/${fixture.name}.png',
      ).writeAsBytes(image.encodePng(photo));
    }
  });
  tearDown(() async {
    cache.clear();
    cache.clearLiveImages();
    await directory.delete(recursive: true);
  });

  group('Square evidence thumbnail decoding', () {
    for (final density in [1.0, 2.0, 2.625, 3.0]) {
      for (final shape in ['wide', 'tall', 'square']) {
        testWidgets('$shape native decode keeps cover detail at DPR $density', (
          tester,
        ) async {
          final capture = _capture(fixtures[shape]!);
          final original = await tester.runAsync(
            () => File(capture.localPath).readAsBytes(),
          );
          await tester.pumpWidget(
            _app(
              density,
              AssessmentEvidenceSelector(
                label: 'Supporting evidence',
                captures: [capture],
                initialIds: const [],
                onChanged: (_) {},
              ),
            ),
          );
          final widget = tester.widget<Image>(find.byType(Image));
          final provider = widget.image as ThumbnailFileImage;
          expect(provider.pixelExtent, (56 * density).ceil());
          expect(widget.fit, BoxFit.cover);
          expect(widget.alignment, Alignment.center);
          final decoded = await _decode(tester, provider);
          final edge = (56 * density).ceil();
          final dimensions = switch (shape) {
            'wide' => (width: edge * 4, height: edge),
            'tall' => (width: edge, height: edge * 4),
            _ => (width: edge, height: edge),
          };
          expect(decoded.width, dimensions.width);
          expect(decoded.height, dimensions.height);
          expect(decoded.bytes, dimensions.width * dimensions.height * 4);
          expect(cache.currentSizeBytes, decoded.bytes);
          expect(
            decoded.bytes,
            lessThan(shape == 'square' ? 512 * 512 * 4 : 1024 * 256 * 4),
          );
          await tester.pump();
          expect(tester.getSize(find.byType(ClipRRect)), const Size(56, 56));
          expect(
            await tester.runAsync(() => File(capture.localPath).readAsBytes()),
            original,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
      'capture and observation selections retain interactions and share a thumbnail',
      (tester) async {
        final capture = _capture(fixtures['wide']!);
        List<String>? selectedCapture;
        List<String>? selectedObservation;
        await tester.pumpWidget(
          _app(
            2,
            Column(
              children: [
                AssessmentEvidenceSelector(
                  label: 'Captures',
                  captures: [capture],
                  initialIds: const [],
                  onChanged: (ids) => selectedCapture = ids,
                ),
                AssessmentObservationSelector(
                  label: 'Observations',
                  captures: [capture],
                  observations: [_observation()],
                  initialIds: const [],
                  onChanged: (ids) => selectedObservation = ids,
                ),
              ],
            ),
          ),
        );
        final providers = tester
            .widgetList<Image>(find.byType(Image))
            .map((value) => value.image)
            .toList();
        expect(providers[0], providers[1]);
        final decoded = await _decode(tester, providers.first);
        expect(decoded.width, 448);
        expect(decoded.height, 112);
        expect(cache.currentSizeBytes, decoded.bytes);
        await tester.tap(find.byKey(const Key('evidence-choice-capture-1')));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('observation-choice-observation-1')),
        );
        await tester.pump();
        expect(selectedCapture, ['capture-1']);
        expect(selectedObservation, ['observation-1']);
        await tester.tap(find.byKey(const Key('evidence-choice-capture-1')));
        await tester.pump();
        expect(selectedCapture, isEmpty);
        expect(selectedObservation, ['observation-1']);
      },
    );

    testWidgets('small source is retained without decode upscaling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          3,
          AssessmentEvidenceSelector(
            label: 'Captures',
            captures: [_capture(fixtures['small']!)],
            initialIds: const [],
            onChanged: (_) {},
          ),
        ),
      );
      final decoded = await _decode(
        tester,
        tester.widget<Image>(find.byType(Image)).image,
      );
      expect((decoded.width, decoded.height), (40, 20));
      expect(decoded.bytes, 40 * 20 * 4);
    });

    testWidgets(
      'DPR cache identities stay distinct from full-resolution observation evidence',
      (tester) async {
        final capture = _capture(fixtures['tall']!);
        final low = ThumbnailFileImage(
          File(capture.localPath),
          pixelExtent: 56,
        );
        final high = ThumbnailFileImage(
          File(capture.localPath),
          pixelExtent: 168,
        );
        expect(low, isNot(high));
        expect(low, isNot(FileImage(File(capture.localPath))));
        await _decode(tester, low);
        await _decode(tester, high);
        await tester.pumpWidget(
          _app(
            3,
            ObservationEvidenceViewer(
              capture: capture,
              observation: _observation(),
            ),
          ),
        );
        final widget = tester.widget<Image>(
          find.byKey(const Key('model-evidence-image-observation-1')),
        );
        expect(widget.image.runtimeType, FileImage);
        final decoded = await _decode(tester, widget.image);
        expect((decoded.width, decoded.height), (256, 1024));
        expect(decoded.bytes, 256 * 1024 * 4);
        expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .maxScale,
          8,
        );
        expect(
          find.byKey(const Key('finding-observation-bounds-observation-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'missing capture fallback permits a retry after cache eviction',
      (tester) async {
        final file = File('${directory.path}/later.png');
        Widget selector(Key key) => AssessmentEvidenceSelector(
          key: key,
          label: 'Captures',
          captures: [_capture(file)],
          initialIds: const [],
          onChanged: (_) {},
        );
        await tester.pumpWidget(_app(2, selector(const Key('missing'))));
        final provider = tester.widget<Image>(find.byType(Image)).image;
        for (
          var attempt = 0;
          find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty &&
              attempt < 250;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 4)),
          );
          await tester.pump();
        }
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        await tester.runAsync(() => fixtures['wide']!.copy(file.path));
        await provider.evict();
        await tester.pumpWidget(_app(2, selector(const Key('retry'))));
        final decoded = await _decode(tester, provider);
        expect((decoded.width, decoded.height), (448, 112));
        await tester.pump();
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Runtime assets', () {
    for (final density in [1.0, 2.0, 2.625, 3.0]) {
      testWidgets(
        'asset native decode follows DPR $density and narrow constraints',
        (tester) async {
          await tester.pumpWidget(
            _app(
              density,
              const Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 70,
                  child: DisplaySizedAssetImage(
                    asset: 'assets/app_icon.png',
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
            ),
          );
          final widget = tester.widget<Image>(find.byType(Image));
          final provider = widget.image as ResizeImage;
          expect(provider.width, (70 * density).ceil());
          expect(provider.height, (100 * density).ceil());
          expect(provider.policy, ResizeImagePolicy.fit);
          expect(provider.allowUpscaling, isFalse);
          final decoded = await _decode(tester, provider);
          expect(
            (decoded.width, decoded.height),
            ((70 * density).ceil(), (70 * density).ceil()),
          );
          expect(cache.currentSizeBytes, decoded.bytes);
          expect(tester.getSize(find.byType(Image)), const Size(70, 100));
        },
      );
    }

    testWidgets('home and login retain 100px logos with DPR-scaled decoding', (
      tester,
    ) async {
      final bloc = AuthBloc(_AuthService());
      addTearDown(bloc.close);
      for (final screen in [const HomeScreen(), const LoginScreen()]) {
        await tester.pumpWidget(
          _app(3, BlocProvider.value(value: bloc, child: screen)),
        );
        final logo = tester.widget<Image>(
          find.descendant(
            of: find.byType(DisplaySizedAssetImage),
            matching: find.byType(Image),
          ),
        );
        final provider = logo.image as ResizeImage;
        expect((logo.width, logo.height), (100, 100));
        expect((provider.width, provider.height), (300, 300));
        final decoded = await _decode(tester, provider);
        expect((decoded.width, decoded.height), (300, 300));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'loading logo and control asset retain tint, size and button action',
      (tester) async {
        await tester.pumpWidget(
          _app(
            3,
            const ModelLoadingOverlay(
              loadingMessage: 'Loading damage model...',
              downloadProgress: .5,
            ),
          ),
        );
        var widget = tester.widget<Image>(find.byType(Image));
        var provider = widget.image as ResizeImage;
        expect((widget.width, widget.height), (120, 120));
        expect((provider.width, provider.height), (360, 360));
        expect(widget.color, Colors.white.withValues(alpha: .8));
        expect(find.text('50.0%'), findsOneWidget);
        var presses = 0;
        await tester.pumpWidget(
          _app(
            3,
            Center(
              child: ControlButton(
                content: 'assets/app_icon.png',
                onPressed: () => presses++,
              ),
            ),
          ),
        );
        widget = tester.widget<Image>(find.byType(Image));
        provider = widget.image as ResizeImage;
        expect((widget.width, widget.height), (24, 24));
        expect((provider.width, provider.height), (72, 72));
        expect(widget.color, Colors.white);
        await tester.tap(find.byType(IconButton));
        expect(presses, 1);
      },
    );
  });
}

Widget _app(double density, Widget child) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(devicePixelRatio: density),
    child: Scaffold(body: child),
  ),
);

Capture _capture(File file) => Capture(
  id: 'capture-1',
  source: CaptureSource.import,
  localPath: file.path,
  acceptedByProfileId: 'appraiser-1',
  acceptedAt: DateTime.utc(2026),
);

DamageObservation _observation() => const DamageObservation(
  id: 'observation-1',
  captureId: 'capture-1',
  rawClass: 'doorouter-dent',
  confidence: .9,
  modelIdentifier: 'best',
  bounds: ObservationBounds(left: .1, top: .2, width: .3, height: .4),
);

Future<({int width, int height, int bytes})> _decode(
  WidgetTester tester,
  ImageProvider provider,
) async {
  ({int width, int height, int bytes})? result;
  Object? failure;
  StackTrace? failureStack;
  late final ImageStream stream;
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      result = (
        width: info.image.width,
        height: info.image.height,
        bytes: info.sizeBytes,
      );
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stack) {
      failure = error;
      failureStack = stack;
      stream.removeListener(listener);
    },
  );
  await tester.runAsync(() async {
    stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(listener);
  });
  // File IO and codecs run asynchronously; delivery also needs a Flutter frame.
  // Bound the wait so a decoder regression produces a failure instead of a hang.
  for (
    var attempt = 0;
    result == null && failure == null && attempt < 250;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
    await tester.pump();
  }
  stream.removeListener(listener);
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack ?? StackTrace.current);
  }
  expect(result, isNotNull, reason: 'Native image decoding did not finish');
  return result!;
}

class _AuthService implements AuthService {
  @override
  Stream<Never> get user => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Authentication not used');
}
