import 'package:autodentifyr/core/theme/theme.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:autodentifyr/presentation/widgets/camera_controls.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_overlay.dart';
import 'package:autodentifyr/presentation/widgets/threshold_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app bar overlay style does not request deprecated bar colors', () {
    final style = AppTheme.darkThemeMode.appBarTheme.systemOverlayStyle;

    expect(style, isNotNull);
    expect(style!.statusBarColor, isNull);
    expect(style.systemNavigationBarColor, isNull);
    expect(style.systemNavigationBarDividerColor, isNull);
  });

  testWidgets('threshold controls stay above the navigation inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        size: const Size(400, 800),
        viewPadding: const EdgeInsets.only(bottom: 48),
        child: ThresholdSlider(
          activeSlider: SliderType.confidence,
          confidenceThreshold: 0.5,
          onValueChanged: (_) {},
          onClose: () {},
          isLandscape: false,
        ),
      ),
    );

    expect(
      tester.getBottomRight(find.byIcon(Icons.close)).dy,
      lessThanOrEqualTo(752),
    );
  });

  testWidgets('camera controls avoid landscape cutout and navigation insets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        size: const Size(800, 400),
        viewPadding: const EdgeInsets.only(right: 60, bottom: 24),
        child: CameraControls(
          currentZoomLevel: 1,
          activeSlider: SliderType.none,
          onZoomChanged: (_) {},
          onSliderToggled: (_) {},
          onCapture: () {},
          isLandscape: true,
        ),
      ),
    );

    final captureBounds = tester.getRect(find.byIcon(Icons.camera_alt));
    expect(captureBounds.right, lessThanOrEqualTo(740));
    expect(captureBounds.bottom, lessThanOrEqualTo(376));
  });

  testWidgets('camera status overlay avoids a landscape display cutout', (
    tester,
  ) async {
    final controller = CameraInferenceController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(
        size: const Size(700, 300),
        viewPadding: const EdgeInsets.only(left: 200),
        child: CameraInferenceOverlay(
          controller: controller,
          isLandscape: true,
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('DETECTIONS: 0')).dx,
      greaterThanOrEqualTo(200),
    );
  });
}

Widget _testApp({
  required Size size,
  required EdgeInsets viewPadding,
  required Widget child,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: Material(child: Stack(children: [child])),
        ),
      ),
    ),
  );
}
