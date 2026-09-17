import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';

/// Renders and interacts with the authored vehicle geometry contract.
class VehicleComponentDiagram extends StatefulWidget {
  const VehicleComponentDiagram({
    super.key,
    required this.view,
    required this.selectedId,
    required this.onSelected,
    this.suggestedId,
    this.onTapResolution,
    this.geometry,
  });

  final VehicleView view;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? suggestedId;
  final ValueChanged<VehicleComponentId> onSelected;
  final ValueChanged<VehicleComponentTapResolution>? onTapResolution;
  final VehicleComponentGeometry? geometry;

  @override
  State<VehicleComponentDiagram> createState() =>
      _VehicleComponentDiagramState();
}

class _VehicleComponentDiagramState extends State<VehicleComponentDiagram> {
  late Future<VehicleComponentGeometry> _geometry;

  @override
  void initState() {
    super.initState();
    _geometry = _loadGeometry();
  }

  @override
  void didUpdateWidget(covariant VehicleComponentDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry) _geometry = _loadGeometry();
  }

  Future<VehicleComponentGeometry> _loadGeometry() => widget.geometry == null
      ? VehicleComponentGeometry.loadAsset()
      : Future.value(widget.geometry!);

  @override
  Widget build(BuildContext context) {
    final suppliedGeometry = widget.geometry;
    if (suppliedGeometry != null) return _surface(suppliedGeometry);
    return FutureBuilder<VehicleComponentGeometry>(
      future: _geometry,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AspectRatio(
            aspectRatio: 5 / 3,
            child: Center(child: Text('Vehicle diagram unavailable')),
          );
        }
        if (!snapshot.hasData) {
          return const AspectRatio(
            aspectRatio: 5 / 3,
            child: Center(
              child: Text(
                'Loading vehicle diagram',
                key: Key('vehicle-component-diagram-loading'),
              ),
            ),
          );
        }
        return _surface(snapshot.requireData);
      },
    );
  }

  Widget _surface(VehicleComponentGeometry geometry) => _GeometrySurface(
    geometry: geometry,
    view: widget.view,
    selectedId: widget.selectedId,
    suggestedId: widget.suggestedId,
    onSelected: widget.onSelected,
    onTapResolution: widget.onTapResolution,
  );
}

class _GeometrySurface extends StatelessWidget {
  const _GeometrySurface({
    required this.geometry,
    required this.view,
    required this.selectedId,
    required this.suggestedId,
    required this.onSelected,
    required this.onTapResolution,
  });

  final VehicleComponentGeometry geometry;
  final VehicleView view;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? suggestedId;
  final ValueChanged<VehicleComponentId> onSelected;
  final ValueChanged<VehicleComponentTapResolution>? onTapResolution;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final geometryView = geometry.view(view);
    return Semantics(
      container: true,
      label: '${_viewLabel(view)} vehicle diagram',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: geometry.width / geometry.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final transform = VehicleComponentGeometryTransform(
                  geometry: geometry,
                  localSize: constraints.biggest,
                );
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const Key('vehicle-component-custom-paint'),
                        painter: _VehicleComponentPainter(
                          geometry: geometry,
                          view: geometryView,
                          transform: transform,
                          selectedId: selectedId,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTapUp: (details) {
                          final point = transform.toNormalized(
                            details.localPosition,
                          );
                          final resolution = point == null
                              ? const VehicleComponentTapMiss()
                              : geometry.resolveTap(view, point);
                          if (onTapResolution case final callback?) {
                            callback(resolution);
                          } else if (resolution case VehicleComponentTapSingle(
                            :final occurrence,
                          )) {
                            onSelected(occurrence.componentId);
                          }
                        },
                      ),
                    ),
                    for (final occurrence
                        in geometryView.occurrences.toList()..sort(
                          (left, right) => left.semanticsOrder.compareTo(
                            right.semanticsOrder,
                          ),
                        ))
                      Positioned.fromRect(
                        rect: transform.toLocalBounds(
                          occurrence.hitBounds,
                          minimumSize: 48,
                        ),
                        child: IgnorePointer(
                          child: Semantics(
                            key: Key(
                              'diagram-component-${occurrence.componentId.wireValue}',
                            ),
                            button: true,
                            selected: selectedId == occurrence.componentId,
                            label: _semanticLabel(
                              occurrence.componentId,
                              selectedId,
                              suggestedId,
                            ),
                            onTap: () => onSelected(occurrence.componentId),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleComponentPainter extends CustomPainter {
  const _VehicleComponentPainter({
    required this.geometry,
    required this.view,
    required this.transform,
    required this.selectedId,
    required this.colorScheme,
  });

  final VehicleComponentGeometry geometry;
  final VehicleComponentGeometryView view;
  final VehicleComponentGeometryTransform transform;
  final VehicleComponentId? selectedId;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    transform.applyTo(canvas);
    canvas.drawPath(view.silhouettePath, Paint()..color = colorScheme.surface);
    canvas.drawPath(
      view.silhouettePath,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / transform.scale,
    );
    for (final decorativePath in view.decorativePaths) {
      canvas.drawPath(
        decorativePath.path,
        Paint()
          ..color = colorScheme.outlineVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / transform.scale,
      );
    }
    for (final occurrence in view.occurrences) {
      final selected = selectedId == occurrence.componentId;
      canvas.drawPath(
        occurrence.visualPath,
        Paint()
          ..color = selected
              ? colorScheme.primary.withValues(alpha: .30)
              : colorScheme.surfaceContainerHighest.withValues(alpha: .78),
      );
      canvas.drawPath(
        occurrence.visualPath,
        Paint()
          ..color = selected ? colorScheme.primary : colorScheme.outlineVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected ? 4 : 1.5) / transform.scale,
      );
      if (selected) _drawCheckmark(canvas, occurrence.visualPath.getBounds());
    }
    canvas.restore();
  }

  void _drawCheckmark(Canvas canvas, ui.Rect bounds) {
    final center = bounds.center;
    final radius = 18 / transform.scale;
    canvas.drawCircle(center, radius, Paint()..color = colorScheme.primary);
    final mark = Path()
      ..moveTo(center.dx - radius * .5, center.dy)
      ..lineTo(center.dx - radius * .12, center.dy + radius * .38)
      ..lineTo(center.dx + radius * .56, center.dy - radius * .4);
    canvas.drawPath(
      mark,
      Paint()
        ..color = colorScheme.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / transform.scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VehicleComponentPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.view != view ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.transform.localSize != transform.localSize;
}

String _semanticLabel(
  VehicleComponentId componentId,
  VehicleComponentId? selectedId,
  VehicleComponentId? suggestedId,
) {
  final state = <String>[];
  if (componentId == selectedId) state.add('Selected');
  if (componentId == suggestedId) state.add('Suggested');
  final label = VehicleComponentCatalog.byId(componentId).label;
  return state.isEmpty ? label : '$label, ${state.join(', ')}';
}

String _viewLabel(VehicleView view) => switch (view) {
  VehicleView.front => 'Front',
  VehicleView.left => 'Left',
  VehicleView.right => 'Right',
  VehicleView.rear => 'Rear',
  VehicleView.top => 'Top',
};
