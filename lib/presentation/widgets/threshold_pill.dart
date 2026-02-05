import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A pill-shaped container for displaying threshold values
class ThresholdPill extends StatelessWidget {
  const ThresholdPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.barBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.whiteColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
