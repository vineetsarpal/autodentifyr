import 'package:flutter/material.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'detection_stats_display.dart';
import 'threshold_pill.dart';

/// Top overlay widget containing model selector, stats, and threshold pills
class CameraInferenceOverlay extends StatelessWidget {
  const CameraInferenceOverlay({
    super.key,
    required this.controller,
    required this.isLandscape,
  });

  final CameraInferenceController controller;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + (isLandscape ? 8 : 16),
      left: isLandscape ? 8 : 16,
      right: isLandscape ? 8 : 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DetectionStatsDisplay(
            detectionCount: controller.detectionCount,
            currentFps: controller.currentFps,
            totalPriceEstimate: controller.totalPriceEstimate,
          ),
          const SizedBox(height: 8),
          _buildThresholdPills(),
        ],
      ),
    );
  }

  Widget _buildThresholdPills() {
    if (controller.activeSlider == SliderType.confidence) {
      return ThresholdPill(
        label:
            'CONFIDENCE THRESHOLD: ${controller.confidenceThreshold.toStringAsFixed(2)}',
      );
    }
    return const SizedBox.shrink();
  }
}
