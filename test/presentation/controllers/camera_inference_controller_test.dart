import 'dart:typed_data';
import 'dart:ui';

import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/models/yolo_result.dart';

void main() {
  group('CameraInferenceController scoped updates', () {
    late CameraInferenceController controller;
    late Map<String, int> updates;

    setUp(() {
      controller = CameraInferenceController();
      updates = {
        'model': 0,
        'detections': 0,
        'stats': 0,
        'controls': 0,
        'capture': 0,
        'all': 0,
      };
      controller.modelChanges.addListener(
        () => updates['model'] = updates['model']! + 1,
      );
      controller.detectionChanges.addListener(
        () => updates['detections'] = updates['detections']! + 1,
      );
      controller.statsChanges.addListener(
        () => updates['stats'] = updates['stats']! + 1,
      );
      controller.controlChanges.addListener(
        () => updates['controls'] = updates['controls']! + 1,
      );
      controller.captureChanges.addListener(
        () => updates['capture'] = updates['capture']! + 1,
      );
      controller.addListener(() => updates['all'] = updates['all']! + 1);
    });

    tearDown(() {
      controller.dispose();
      // The controller's stream cleanup is a separate optimization item.
      controller.yoloController.dispose();
    });

    test('delivers every result while unchanged stats remain stable', () {
      final first = [_result('bonnet-dent')];
      final moved = [_result('bonnet-dent', left: .3)];
      controller.onDetectionResults(first);
      controller.onDetectionResults(moved);

      expect(controller.currentResults, same(moved));
      expect(controller.currentResults.single.normalizedBox.left, .3);
      expect(controller.detectionCount, 1);
      expect(controller.totalPriceEstimate, 450);
      expect(updates, {
        'model': 0,
        'detections': 2,
        'stats': 1,
        'controls': 0,
        'capture': 0,
        'all': 2,
      });
    });

    test(
      'updates stats when price or count changes, including empty results',
      () {
        controller.onDetectionResults([_result('bonnet-dent')]);
        controller.onDetectionResults([_result('doorouter-dent')]);
        expect(controller.totalPriceEstimate, 500);
        controller.onDetectionResults([
          _result('UNKNOWN'),
          _result('BONNET-DENT'),
        ]);
        expect(controller.totalPriceEstimate, 700);
        expect(controller.detectionCount, 2);
        controller.onDetectionResults([]);
        expect(controller.totalPriceEstimate, 0);
        expect(controller.detectionCount, 0);
        expect(updates['stats'], 4);
        expect(updates['detections'], 4);
      },
    );

    test('FPS retains its threshold and only updates stats listeners', () {
      controller.onPerformanceMetrics(30);
      controller.onPerformanceMetrics(30.05);
      expect(controller.currentFps, 30);
      expect(updates['stats'], 1);
      controller.onPerformanceMetrics(29.8);
      expect(controller.currentFps, 29.8);
      expect(updates['stats'], 2);
      expect(updates['all'], 2);
      expect(updates['detections'], 0);
      expect(updates['model'], 0);
      expect(updates['controls'], 0);
    });

    test('threshold and zoom actions only notify controls', () {
      controller.updateSliderValue(.7);
      expect(controller.confidenceThreshold, .5);
      controller.toggleSlider(SliderType.confidence);
      controller.updateSliderValue(.7);
      expect(controller.confidenceThreshold, .7);
      expect(controller.yoloController.confidenceThreshold, .7);
      controller.setZoomLevel(3);
      controller.onZoomChanged(.5);
      controller.toggleSlider(SliderType.confidence);
      expect(controller.currentZoomLevel, .5);
      expect(controller.activeSlider, SliderType.none);
      expect(updates['controls'], 5);
      expect(updates['all'], 5);
      expect(updates['detections'], 0);
      expect(updates['stats'], 0);
      expect(updates['model'], 0);
      expect(updates['capture'], 0);
    });

    test(
      'capture and clear retain bytes and only notify capture listeners',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        await controller.setCapturedImage(bytes);
        expect(controller.capturedImage, same(bytes));
        controller.clearCapturedImage();
        expect(controller.capturedImage, isNull);
        expect(updates['capture'], 2);
        expect(updates['all'], 2);
        expect(updates['detections'], 0);
        expect(updates['stats'], 0);
        expect(updates['controls'], 0);
        expect(updates['model'], 0);
      },
    );
  });
}

YOLOResult _result(String label, {double left = .1}) => YOLOResult(
  classIndex: 0,
  className: label,
  confidence: .9,
  boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
  normalizedBox: Rect.fromLTWH(left, .2, .3, .4),
);
