import 'dart:typed_data';

import 'package:autodentifyr/core/theme/theme.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:autodentifyr/presentation/widgets/bounding_box_overlay.dart';
import 'package:autodentifyr/presentation/widgets/camera_controls.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_body.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_content.dart';
import 'package:autodentifyr/presentation/widgets/detection_stats_display.dart';
import 'package:autodentifyr/presentation/widgets/threshold_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/models/yolo_result.dart';

void main() {
  group('Live camera update isolation', () {
    late CameraInferenceController controller;
    late GlobalKey captureKey;

    setUp(() {
      controller = CameraInferenceController();
      captureKey = GlobalKey();
    });
    tearDown(() {
      controller.dispose();
      controller.yoloController.dispose();
    });

    Future<void> pumpBody(
      WidgetTester tester, {
      VoidCallback? onCapture,
      WidgetBuilder? capturedImageBuilder,
      bool isLandscape = false,
      int rebuildKey = 0,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkThemeMode,
        home: Scaffold(
          body: CameraInferenceBody(
            controller: controller,
            rebuildKey: rebuildKey,
            isLandscape: isLandscape,
            captureKey: captureKey,
            onCapture: onCapture ?? () {},
            capturedImageBuilder:
                capturedImageBuilder ?? (_) => const Text('Captured preview'),
          ),
        ),
      ),
    );

    testWidgets(
      'moving detections update boxes without rebuilding camera, controls or unchanged stats',
      (tester) async {
        await pumpBody(tester);
        controller.onDetectionResults([_result(.1)]);
        await tester.pump();
        expect(find.text('DETECTIONS: 1'), findsOneWidget);
        expect(find.text('\$450'), findsNWidgets(2));
        final camera = tester.widget(find.byType(CameraInferenceContent));
        final controls = tester.widget(find.byType(CameraControls));
        final slider = tester.widget(find.byType(ThresholdSlider));
        final stats = tester.widget(find.byType(DetectionStatsDisplay));
        final boxes = tester.widget(find.byType(BoundingBoxOverlay));

        for (final left in [.2, .3, .4]) {
          controller.onDetectionResults([_result(left)]);
          await tester.pump();
          expect(
            tester.widget(find.byType(CameraInferenceContent)),
            same(camera),
          );
          expect(tester.widget(find.byType(CameraControls)), same(controls));
          expect(tester.widget(find.byType(ThresholdSlider)), same(slider));
          expect(
            tester.widget(find.byType(DetectionStatsDisplay)),
            same(stats),
          );
          final overlay = tester.widget<BoundingBoxOverlay>(
            find.byType(BoundingBoxOverlay),
          );
          expect(overlay, isNot(same(boxes)));
          expect(overlay.results.single.normalizedBox.left, left);
        }
        controller.onDetectionResults([]);
        await tester.pump();
        expect(find.text('DETECTIONS: 0'), findsOneWidget);
        expect(find.text('\$450'), findsNothing);
        expect(
          tester.widget(find.byType(CameraInferenceContent)),
          same(camera),
        );
      },
    );

    testWidgets('FPS updates leave camera and bounding boxes stable', (
      tester,
    ) async {
      await pumpBody(tester);
      final camera = tester.widget(find.byType(CameraInferenceContent));
      final boxes = tester.widget(find.byType(BoundingBoxOverlay));
      final controls = tester.widget(find.byType(CameraControls));
      controller.onPerformanceMetrics(27.25);
      await tester.pump();
      expect(find.text('FPS: 27.3'), findsOneWidget);
      expect(tester.widget(find.byType(CameraInferenceContent)), same(camera));
      expect(tester.widget(find.byType(BoundingBoxOverlay)), same(boxes));
      expect(tester.widget(find.byType(CameraControls)), same(controls));
    });

    testWidgets(
      'threshold, zoom and capture controls keep their interactions',
      (tester) async {
        var captures = 0;
        await pumpBody(tester, onCapture: () => captures++);
        final camera = tester.widget(find.byType(CameraInferenceContent));
        final stats = tester.widget(find.byType(DetectionStatsDisplay));
        await tester.tap(find.byIcon(Icons.adjust));
        await tester.pump();
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('CONFIDENCE THRESHOLD: 0.50'), findsOneWidget);
        tester.widget<Slider>(find.byType(Slider)).onChanged!(.7);
        await tester.pump();
        expect(find.text('CONFIDENCE THRESHOLD: 0.70'), findsOneWidget);
        expect(controller.yoloController.confidenceThreshold, .7);
        await tester.tap(find.text('1.0x'));
        await tester.pump();
        expect(find.text('3.0x'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(find.byType(Slider), findsNothing);
        await tester.tap(find.byIcon(Icons.camera_alt));
        expect(captures, 1);
        expect(
          tester.widget(find.byType(CameraInferenceContent)),
          same(camera),
        );
        expect(tester.widget(find.byType(DetectionStatsDisplay)), same(stats));
      },
    );

    testWidgets('captured preview stays stable during inference and closes', (
      tester,
    ) async {
      var previewBuilds = 0;
      await pumpBody(
        tester,
        capturedImageBuilder: (_) {
          previewBuilds++;
          return const Text('Captured preview');
        },
      );
      await controller.setCapturedImage(Uint8List.fromList([1]));
      await tester.pump();
      expect(find.text('Captured preview'), findsOneWidget);
      expect(previewBuilds, 1);
      controller.onDetectionResults([_result(.2)]);
      controller.onPerformanceMetrics(25);
      await tester.pump();
      expect(previewBuilds, 1);
      controller.clearCapturedImage();
      await tester.pump();
      expect(find.text('Captured preview'), findsNothing);
    });

    testWidgets(
      'capture boundary contains boxes and stats but excludes controls',
      (tester) async {
        await pumpBody(tester);
        final boundary = find.byKey(captureKey);
        expect(
          find.descendant(
            of: boundary,
            matching: find.byType(BoundingBoxOverlay),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: boundary,
            matching: find.byType(DetectionStatsDisplay),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: boundary, matching: find.byType(CameraControls)),
          findsNothing,
        );
        expect(
          find.descendant(of: boundary, matching: find.byType(ThresholdSlider)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'orientation and explicit restart still reach the camera and controls',
      (tester) async {
        await pumpBody(tester);
        await pumpBody(tester, isLandscape: true, rebuildKey: 1);
        expect(
          tester
              .widget<CameraControls>(find.byType(CameraControls))
              .isLandscape,
          isTrue,
        );
        final camera = tester.widget<CameraInferenceContent>(
          find.byType(CameraInferenceContent),
        );
        expect(camera.rebuildKey, 1);
        expect(camera.key, const ValueKey('camera_content_1'));
      },
    );
  });
}

YOLOResult _result(double left) => YOLOResult(
  classIndex: 0,
  className: 'bonnet-dent',
  confidence: .9,
  boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
  normalizedBox: Rect.fromLTWH(left, .2, .3, .4),
);
