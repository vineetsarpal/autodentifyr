import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bounds asset decoding by its constrained display size and device density.
class DisplaySizedAssetImage extends StatelessWidget {
  const DisplaySizedAssetImage({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.color,
  });

  final String asset;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final displaySize = constraints.constrain(Size(width, height));
      final density = MediaQuery.devicePixelRatioOf(context);
      return Image(
        image: ResizeImage(
          AssetImage(asset),
          width: math.max(1, (displaySize.width * density).ceil()),
          height: math.max(1, (displaySize.height * density).ceil()),
          policy: ResizeImagePolicy.fit,
        ),
        width: width,
        height: height,
        color: color,
      );
    },
  );
}
