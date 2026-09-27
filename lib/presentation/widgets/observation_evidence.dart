import 'dart:io';

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';

/// A photo with a normalized model observation drawn over it.
///
/// The supplied keys intentionally let callers keep stable widget-test hooks
/// for a given evidence context.
class ObservationImageOverlay extends StatelessWidget {
  const ObservationImageOverlay({
    super.key,
    required this.capture,
    required this.observation,
    required this.imageKey,
    required this.boundsKey,
    required this.outlineColor,
  });

  final Capture capture;
  final DamageObservation observation;
  final Key imageKey;
  final Key boundsKey;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: FittedBox(
      fit: BoxFit.contain,
      child: Stack(
        children: [
          Image.file(
            File(capture.localPath),
            key: imageKey,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 4,
              height: 3,
              child: ColoredBox(
                color: Colors.black12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: boundsKey,
                painter: _ObservationBoundsPainter(
                  bounds: observation.bounds,
                  color: outlineColor,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Full-screen, zoomable model evidence for one observation-backed capture.
class ObservationEvidenceViewer extends StatelessWidget {
  const ObservationEvidenceViewer({
    super.key,
    required this.capture,
    required this.observation,
    this.closeKey = const Key('close-model-evidence'),
    this.imageKey,
    this.boundsKey,
  });

  final Capture capture;
  final DamageObservation observation;
  final Key closeKey;
  final Key? imageKey;
  final Key? boundsKey;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: CloseButton(
        key: closeKey,
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Model evidence'),
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${observation.rawClass} • '
                  '${(observation.confidence * 100).toStringAsFixed(1)}% '
                  'confidence',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('Pinch to zoom and drag to inspect the detection.'),
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(80),
              child: ObservationImageOverlay(
                capture: capture,
                observation: observation,
                imageKey:
                    imageKey ?? Key('model-evidence-image-${observation.id}'),
                boundsKey:
                    boundsKey ??
                    Key('finding-observation-bounds-${observation.id}'),
                outlineColor: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ObservationBoundsPainter extends CustomPainter {
  const _ObservationBoundsPainter({required this.bounds, required this.color});

  final ObservationBounds bounds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final left = bounds.left.clamp(0.0, 1.0).toDouble();
    final top = bounds.top.clamp(0.0, 1.0).toDouble();
    final right = (bounds.left + bounds.width).clamp(0.0, 1.0).toDouble();
    final bottom = (bounds.top + bounds.height).clamp(0.0, 1.0).toDouble();
    final rectangle = Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );
    final shadow = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rectangle, shadow);
    canvas.drawRect(rectangle, outline);
  }

  @override
  bool shouldRepaint(_ObservationBoundsPainter oldDelegate) =>
      oldDelegate.bounds != bounds || oldDelegate.color != color;
}
