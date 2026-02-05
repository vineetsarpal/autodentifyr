import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/models/yolo_result.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// An overlay that draws price estimates next to detected bounding boxes
class BoundingBoxOverlay extends StatelessWidget {
  const BoundingBoxOverlay({
    super.key,
    required this.results,
    required this.controller,
  });

  final List<YOLOResult> results;
  final CameraInferenceController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: results.map((result) {
            final box = result.normalizedBox;

            // Convert normalized coordinates to screen pixels
            final left = box.left * constraints.maxWidth;
            final top = box.top * constraints.maxHeight;

            final price = controller.getPriceForLabel(result.className);

            return Positioned(
              left: left,
              top: top,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.yellowColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.blackColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppPalette.blackColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
