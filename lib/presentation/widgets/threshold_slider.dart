import 'package:flutter/material.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A slider widget for adjusting threshold values
class ThresholdSlider extends StatelessWidget {
  const ThresholdSlider({
    super.key,
    required this.activeSlider,
    required this.confidenceThreshold,
    required this.onValueChanged,
    required this.onClose,
    required this.isLandscape,
  });

  final SliderType activeSlider;
  final double confidenceThreshold;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onClose;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    if (activeSlider == SliderType.none) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 16 : 24,
          vertical: isLandscape ? 8 : 12,
        ),
        color: AppPalette.overlayBackgroundColor,
        child: Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppPalette.yellowColor,
                  inactiveTrackColor: AppPalette.inactiveTrackColor,
                  thumbColor: AppPalette.yellowColor,
                  overlayColor: AppPalette.sliderOverlayColor,
                ),
                child: Slider(
                  value: confidenceThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 8,
                  label: confidenceThreshold.toStringAsFixed(1),
                  onChanged: onValueChanged,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppPalette.whiteColor),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
