import 'package:flutter/material.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';
import 'control_button.dart';

/// A widget containing camera control buttons
class CameraControls extends StatelessWidget {
  const CameraControls({
    super.key,
    required this.currentZoomLevel,
    required this.activeSlider,
    required this.onZoomChanged,
    required this.onSliderToggled,
    required this.onCapture,
    required this.isLandscape,
    this.isCapturing = false,
  });

  final double currentZoomLevel;
  final SliderType activeSlider;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<SliderType> onSliderToggled;
  final VoidCallback onCapture;
  final bool isLandscape;
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: isLandscape ? 60 : 80,
          right: isLandscape ? 8 : 16,
          child: Column(
            children: [
              ControlButton(
                content: '${currentZoomLevel.toStringAsFixed(1)}x',
                onPressed: () => onZoomChanged(
                  currentZoomLevel < 0.75
                      ? 1.0
                      : currentZoomLevel < 2.0
                      ? 3.0
                      : 0.5,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 12),
              ControlButton(
                content: Icons.adjust,
                onPressed: () => onSliderToggled(SliderType.confidence),
              ),
              SizedBox(height: isLandscape ? 12 : 24),
              CircleAvatar(
                radius: isLandscape ? 24 : 32,
                backgroundColor: AppPalette.whiteColor,
                child: CircleAvatar(
                  radius: isLandscape ? 22 : 30,
                  backgroundColor: AppPalette.overlayBackgroundColor,
                  child: isCapturing
                      ? const CircularProgressIndicator(
                          color: AppPalette.whiteColor,
                        )
                      : IconButton(
                          iconSize: isLandscape ? 28 : 36,
                          icon: const Icon(
                            Icons.camera_alt,
                            color: AppPalette.whiteColor,
                          ),
                          onPressed: onCapture,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
