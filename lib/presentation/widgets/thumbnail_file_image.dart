import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Decodes enough pixels for a square cover thumbnail without changing aspect.
/// The cache key stays separate from full-resolution evidence and other DPRs.
class ThumbnailFileImage extends FileImage {
  const ThumbnailFileImage(super.file, {required this.pixelExtent})
    : assert(pixelExtent > 0);

  final int pixelExtent;

  @override
  ImageStreamCompleter loadImage(
    FileImage key,
    ImageDecoderCallback decode,
  ) => super.loadImage(
    key,
    (buffer, {getTargetSize}) => decode(
      buffer,
      getTargetSize: (width, height) {
        // Retain small originals. Setting only the short edge lets the native
        // decoder derive the other dimension at the original aspect ratio.
        if (width <= pixelExtent || height <= pixelExtent) {
          return const ui.TargetImageSize();
        }
        return width >= height
            ? ui.TargetImageSize(height: pixelExtent)
            : ui.TargetImageSize(width: pixelExtent);
      },
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is ThumbnailFileImage &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.pixelExtent == pixelExtent;

  @override
  int get hashCode => Object.hash(file.path, scale, pixelExtent);
}
