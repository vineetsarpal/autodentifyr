import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:autodentifyr/presentation/widgets/bounding_box_overlay.dart';
import 'package:autodentifyr/presentation/widgets/camera_controls.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_content.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_overlay.dart';
import 'package:autodentifyr/presentation/widgets/threshold_slider.dart';
import 'package:flutter/material.dart';

/// Keeps camera, detection, control, and capture updates in separate subtrees.
class CameraInferenceBody extends StatelessWidget {
  const CameraInferenceBody({
    super.key,
    required this.controller,
    required this.rebuildKey,
    required this.isLandscape,
    required this.captureKey,
    required this.onCapture,
    required this.capturedImageBuilder,
  });

  final CameraInferenceController controller;
  final int rebuildKey;
  final bool isLandscape;
  final GlobalKey captureKey;
  final VoidCallback onCapture;
  final WidgetBuilder capturedImageBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          key: captureKey,
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: controller.modelChanges,
                builder: (context, _) => CameraInferenceContent(
                  key: ValueKey('camera_content_$rebuildKey'),
                  controller: controller,
                  rebuildKey: rebuildKey,
                ),
              ),
              ListenableBuilder(
                listenable: controller.detectionChanges,
                builder: (context, _) => BoundingBoxOverlay(
                  results: controller.currentResults,
                  controller: controller,
                ),
              ),
              CameraInferenceOverlay(
                controller: controller,
                isLandscape: isLandscape,
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: controller.controlChanges,
          builder: (context, _) => ThresholdSlider(
            activeSlider: controller.activeSlider,
            confidenceThreshold: controller.confidenceThreshold,
            onValueChanged: controller.updateSliderValue,
            onClose: () => controller.toggleSlider(SliderType.none),
            isLandscape: isLandscape,
          ),
        ),
        ListenableBuilder(
          listenable: controller.controlChanges,
          builder: (context, _) => CameraControls(
            currentZoomLevel: controller.currentZoomLevel,
            activeSlider: controller.activeSlider,
            onZoomChanged: controller.setZoomLevel,
            onSliderToggled: controller.toggleSlider,
            onCapture: onCapture,
            isLandscape: isLandscape,
            isCapturing: controller.isCapturing,
          ),
        ),
        ListenableBuilder(
          listenable: controller.captureChanges,
          builder: (context, _) => controller.capturedImage == null
              ? const SizedBox.shrink()
              : capturedImageBuilder(context),
        ),
      ],
    );
  }
}
