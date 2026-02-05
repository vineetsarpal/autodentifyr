import 'package:flutter/material.dart';

class AppPalette {
  // Brand Colors
  static const Color appBlue = Color(0xFF0D263D);
  static const Color appGreen = Color(0xFF04D9FF);

  // Base Colors
  static const Color whiteColor = Colors.white;
  static const Color blackColor = Colors.black;
  static const Color greyColor = Colors.grey;
  static const Color transparentColor = Colors.transparent;

  // UI Colors
  static const Color errorColor = Colors.redAccent;
  static const Color redColor = Colors.red;
  static const Color blueColor = Colors.blue;
  static const Color yellowColor = Colors.yellow;
  static const Color successColor = Colors.green;

  // Semantic Colors
  static final Color white70 = Colors.white.withValues(alpha: 0.7);
  static final Color barBackgroundColor = Colors.black.withValues(alpha: 0.5);
  static final Color overlayBackgroundColor = Colors.black.withValues(
    alpha: 0.8,
  );
  static final Color shadowColor = Colors.black.withValues(alpha: 0.1);
  static final Color textFieldFillColor = Colors.white.withValues(alpha: 0.05);
  static final Color inactiveTrackColor = Colors.white.withValues(alpha: 0.3);
  static final Color sliderOverlayColor = Colors.yellow.withValues(alpha: 0.2);
  static final Color separatorColor = Colors.white.withValues(alpha: 0.2);
}
