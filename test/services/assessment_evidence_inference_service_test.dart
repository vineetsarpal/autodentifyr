import 'dart:async';

import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/model_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/yolo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('YoloEvidenceInferenceService', () {
    test(
      'real YOLO routes owned lifecycle through an isolated native instance',
      () async {
        const defaultChannel = MethodChannel('yolo_single_image_channel');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final defaultCalls = <String>[];
        final instanceCalls = <MethodCall>[];
        MethodChannel? instanceChannel;
        String? instanceId;
        messenger.setMockMethodCallHandler(defaultChannel, (call) async {
          defaultCalls.add(call.method);
          if (call.method == 'inspectModel') return {'task': 'detect'};
          if (call.method == 'createInstance') {
            instanceId = (call.arguments as Map)['instanceId'] as String;
            instanceChannel = MethodChannel(
              'yolo_single_image_channel_$instanceId',
            );
            messenger.setMockMethodCallHandler(instanceChannel!, (call) async {
              instanceCalls.add(call);
              return switch (call.method) {
                'loadModel' => true,
                'predictSingleImage' => {'boxes': []},
                _ => null,
              };
            });
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(defaultChannel, null);
          if (instanceChannel != null) {
            messenger.setMockMethodCallHandler(instanceChannel!, null);
          }
        });
        final service = YoloEvidenceInferenceService(
          modelManager: _ModelManager(),
        );
        await service.analyze(Uint8List.fromList([1]));
        await service.dispose();
        expect(instanceId, isNot('default'));
        expect(defaultCalls, ['inspectModel', 'createInstance']);
        expect(instanceCalls.map((call) => call.method), [
          'loadModel',
          'predictorInstance',
          'predictSingleImage',
          'disposeInstance',
        ]);
        for (final call in instanceCalls) {
          expect((call.arguments as Map)['instanceId'], instanceId);
        }
        final load = instanceCalls.first.arguments as Map;
        expect(load['task'], 'detect');
        expect(load['useGpu'], true);
        expect(load['numItemsThreshold'], 30);
        final predict = instanceCalls[2].arguments as Map;
        expect(predict.containsKey('confidenceThreshold'), false);
        expect(predict.containsKey('iouThreshold'), false);
      },
    );
    test(
      'loads lazily once and preserves predictions and observation mapping',
      () async {
        final manager = _ModelManager();
        final yolo = _Yolo();
        final service = YoloEvidenceInferenceService(
          modelManager: manager,
          createYolo: (_) => yolo,
        );
        expect(manager.calls, 0);
        final bytes = Uint8List.fromList([1, 2]);
        final result = await service.analyze(bytes);
        await service.analyze(bytes);
        expect(manager.calls, 1);
        expect(yolo.loads, 1);
        expect(yolo.warmups, 1);
        expect(yolo.inputs, [same(bytes), same(bytes)]);
        expect(yolo.thresholds, [(null, null), (null, null)]);
        expect(result.annotatedImageBytes, [9]);
        final observation = result.observations.single;
        expect(observation.rawClass, 'doorouter-dent');
        expect(observation.confidence, 0.87);
        expect(observation.bounds.left, 0.1);
        expect(observation.bounds.top, 0.2);
        expect(observation.bounds.width, closeTo(0.3, 0.00001));
        expect(observation.bounds.height, closeTo(0.4, 0.00001));
        expect(observation.modelIdentifier, 'damage.tflite');
        expect(
          observation.runtimeIdentifier,
          YoloEvidenceInferenceService.runtimeIdentifier,
        );
        await service.dispose();
        expect(yolo.disposals, 1);
      },
    );

    test('serializes predictions and continues after a failed image', () async {
      final first = Completer<Map<String, dynamic>>();
      final entered = Completer<void>();
      final yolo = _Yolo()
        ..onPredict = (bytes) {
          if (bytes.single == 1) {
            entered.complete();
            return first.future;
          }
          return Future.value({});
        };
      final service = YoloEvidenceInferenceService(
        modelManager: _ModelManager(),
        createYolo: (_) => yolo,
      );
      final failed = service.analyze(Uint8List.fromList([1]));
      final failure = expectLater(failed, throwsStateError);
      final succeeding = service.analyze(Uint8List.fromList([2]));
      await entered.future;
      expect(yolo.inputs.length, 1);
      first.completeError(StateError('invalid image'));
      await failure;
      final result = await succeeding;
      expect(result.annotatedImageBytes, [2]);
      expect(result.observations, isEmpty);
      expect(yolo.loads, 1);
      expect(yolo.inputs.map((bytes) => bytes.single), [1, 2]);
      await service.dispose();
    });

    for (final failureAt in ['load', 'warmup']) {
      test('cleans partial $failureAt failure and reloads on retry', () async {
        final failed = _Yolo();
        if (failureAt == 'load') {
          failed.onLoad = () async => false;
        } else {
          failed.onWarmup = () async => throw StateError('warmup failed');
        }
        final healthy = _Yolo();
        final engines = [failed, healthy];
        final manager = _ModelManager();
        final service = YoloEvidenceInferenceService(
          modelManager: manager,
          createYolo: (_) => engines.removeAt(0),
        );
        await expectLater(service.analyze(Uint8List(1)), throwsStateError);
        expect(failed.disposals, 1);
        await service.analyze(Uint8List(1));
        expect(manager.calls, 2);
        expect(healthy.loads, 1);
        await service.dispose();
        expect(healthy.disposals, 1);
      });
    }

    test(
      'unavailable model can become available on the next attempt',
      () async {
        final manager = _ModelManager()..unavailable = true;
        final yolo = _Yolo();
        final service = YoloEvidenceInferenceService(
          modelManager: manager,
          createYolo: (_) => yolo,
        );
        await expectLater(service.analyze(Uint8List(1)), throwsStateError);
        expect(yolo.loads, 0);
        manager.unavailable = false;
        await service.analyze(Uint8List(1));
        await service.dispose();
      },
    );

    test(
      'disposal drains accepted work during initialization and rejects new work',
      () async {
        final load = Completer<bool>();
        final entered = Completer<void>();
        final yolo = _Yolo()
          ..onLoad = () {
            entered.complete();
            return load.future;
          };
        final service = YoloEvidenceInferenceService(
          modelManager: _ModelManager(),
          createYolo: (_) => yolo,
        );
        final first = service.analyze(Uint8List.fromList([1]));
        final second = service.analyze(Uint8List.fromList([2]));
        await entered.future;
        final disposal = service.dispose();
        expect(service.dispose(), same(disposal));
        await expectLater(service.analyze(Uint8List(1)), throwsStateError);
        expect(yolo.disposals, 0);
        load.complete(true);
        await Future.wait([first, second]);
        await disposal;
        expect(yolo.inputs.map((bytes) => bytes.single), [1, 2]);
        expect(yolo.disposals, 1);
      },
    );

    test('disposal waits for an active prediction', () async {
      final prediction = Completer<Map<String, dynamic>>();
      final entered = Completer<void>();
      final yolo = _Yolo()
        ..onPredict = (_) {
          entered.complete();
          return prediction.future;
        };
      final service = YoloEvidenceInferenceService(
        modelManager: _ModelManager(),
        createYolo: (_) => yolo,
      );
      final analysis = service.analyze(Uint8List(1));
      await entered.future;
      final disposal = service.dispose();
      expect(yolo.disposals, 0);
      prediction.complete({});
      await analysis;
      await disposal;
      expect(yolo.disposals, 1);
    });

    test(
      'unused workflow disposal does not resolve or construct a model',
      () async {
        final manager = _ModelManager();
        final service = YoloEvidenceInferenceService(
          modelManager: manager,
          createYolo: (_) => throw StateError('must stay lazy'),
        );
        await service.dispose();
        await service.dispose();
        expect(manager.calls, 0);
      },
    );
  });
}

class _ModelManager extends ModelManager {
  int calls = 0;
  bool unavailable = false;
  @override
  Future<String?> getModelPath(ModelType modelType) async {
    calls++;
    return unavailable ? null : '/models/damage.tflite';
  }
}

class _Yolo extends YOLO {
  _Yolo() : super(modelPath: '/models/damage.tflite');
  int loads = 0;
  int warmups = 0;
  int disposals = 0;
  final inputs = <Uint8List>[];
  final thresholds = <(double?, double?)>[];
  Future<bool> Function()? onLoad;
  Future<void> Function()? onWarmup;
  Future<Map<String, dynamic>> Function(Uint8List)? onPredict;

  @override
  Future<bool> loadModel() async {
    loads++;
    return await onLoad?.call() ?? true;
  }

  @override
  Future<void> predictorInstance() async {
    warmups++;
    await onWarmup?.call();
  }

  @override
  Future<Map<String, dynamic>> predict(
    Uint8List imageBytes, {
    double? confidenceThreshold,
    double? iouThreshold,
  }) async {
    inputs.add(imageBytes);
    thresholds.add((confidenceThreshold, iouThreshold));
    return await onPredict?.call(imageBytes) ??
        {
          'annotatedImage': Uint8List.fromList([9]),
          'detections': [
            {
              'className': 'doorouter-dent',
              'confidence': 0.87,
              'normalizedBox': {
                'left': 0.1,
                'top': 0.2,
                'right': 0.4,
                'bottom': 0.6,
              },
            },
          ],
        };
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
