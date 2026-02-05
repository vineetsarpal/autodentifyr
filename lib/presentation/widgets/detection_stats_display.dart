import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A widget that displays detection statistics (count and FPS)
class DetectionStatsDisplay extends StatelessWidget {
  const DetectionStatsDisplay({
    super.key,
    required this.detectionCount,
    required this.currentFps,
    required this.totalPriceEstimate,
  });

  final int detectionCount;
  final double currentFps;
  final double totalPriceEstimate;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.barBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETECTIONS: $detectionCount',
                  style: const TextStyle(
                    color: AppPalette.whiteColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'FPS: ${currentFps.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppPalette.white70,
                    fontWeight: FontWeight.w400,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Container(height: 30, width: 1, color: AppPalette.separatorColor),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL ESTIMATE',
                  style: TextStyle(
                    color: AppPalette.yellowColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '\$${totalPriceEstimate.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppPalette.yellowColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
