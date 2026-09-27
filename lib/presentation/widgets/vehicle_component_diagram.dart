import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';

/// Renders and interacts with the authored vehicle geometry contract.
class VehicleComponentDiagram extends StatefulWidget {
  const VehicleComponentDiagram({
    super.key,
    required this.view,
    required this.selectedId,
    required this.onSelected,
    this.suggestedId,
    this.candidateIds = const [],
    this.existingFindings = const [],
    this.onExistingFindingSelected,
    this.onTapResolution,
    this.geometry,
  });

  final VehicleView view;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? suggestedId;
  final List<VehicleComponentId> candidateIds;
  final List<VehicleComponentExistingFinding> existingFindings;
  final ValueChanged<VehicleComponentExistingFinding>?
  onExistingFindingSelected;
  final ValueChanged<VehicleComponentId> onSelected;
  final ValueChanged<VehicleComponentTapResolution>? onTapResolution;
  final VehicleComponentGeometry? geometry;

  @override
  State<VehicleComponentDiagram> createState() =>
      _VehicleComponentDiagramState();
}

class _VehicleComponentDiagramState extends State<VehicleComponentDiagram>
    with SingleTickerProviderStateMixin {
  static const _selectionDuration = Duration(milliseconds: 200);

  late Future<VehicleComponentGeometry> _geometry;
  late final AnimationController _selectionController;
  VehicleComponentId? _previousSelectedId;
  VehicleComponentId? _pressedComponentId;

  @override
  void initState() {
    super.initState();
    _geometry = _loadGeometry();
    _selectionController = AnimationController(
      vsync: this,
      duration: _selectionDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant VehicleComponentDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry) _geometry = _loadGeometry();
    if (oldWidget.selectedId != widget.selectedId) {
      _previousSelectedId = oldWidget.selectedId;
      if (_reducedMotion) {
        _previousSelectedId = null;
        _selectionController.value = 1;
      } else {
        _selectionController.forward(from: 0);
      }
    }
  }

  bool get _reducedMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  Future<VehicleComponentGeometry> _loadGeometry() => widget.geometry == null
      ? VehicleComponentGeometry.loadAsset()
      : Future.value(widget.geometry!);

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

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

  Widget _surface(VehicleComponentGeometry geometry) => AnimatedBuilder(
    animation: _selectionController,
    builder: (context, _) => _GeometrySurface(
      geometry: geometry,
      view: widget.view,
      selectedId: widget.selectedId,
      previousSelectedId: _previousSelectedId,
      selectionProgress: _selectionController.value,
      suggestedId: widget.suggestedId,
      candidateIds: widget.candidateIds,
      pressedComponentId: _pressedComponentId,
      onPressedComponentChanged: (componentId) =>
          setState(() => _pressedComponentId = componentId),
      existingFindings: widget.existingFindings,
      onExistingFindingSelected: widget.onExistingFindingSelected,
      onSelected: widget.onSelected,
      onTapResolution: widget.onTapResolution,
    ),
  );
}

class _GeometrySurface extends StatelessWidget {
  const _GeometrySurface({
    required this.geometry,
    required this.view,
    required this.selectedId,
    required this.previousSelectedId,
    required this.selectionProgress,
    required this.suggestedId,
    required this.candidateIds,
    required this.pressedComponentId,
    required this.onPressedComponentChanged,
    required this.existingFindings,
    required this.onExistingFindingSelected,
    required this.onSelected,
    required this.onTapResolution,
  });

  final VehicleComponentGeometry geometry;
  final VehicleView view;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? previousSelectedId;
  final double selectionProgress;
  final VehicleComponentId? suggestedId;
  final List<VehicleComponentId> candidateIds;
  final VehicleComponentId? pressedComponentId;
  final ValueChanged<VehicleComponentId?> onPressedComponentChanged;
  final List<VehicleComponentExistingFinding> existingFindings;
  final ValueChanged<VehicleComponentExistingFinding>?
  onExistingFindingSelected;
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
                          previousSelectedId: previousSelectedId,
                          selectionProgress: selectionProgress,
                          suggestedId: suggestedId,
                          candidateIds: candidateIds,
                          pressedComponentId: pressedComponentId,
                          existingFindings: existingFindings,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTapDown: (details) {
                          final point = transform.toNormalized(
                            details.localPosition,
                          );
                          final resolution = point == null
                              ? const VehicleComponentTapMiss()
                              : geometry.resolveTap(view, point);
                          onPressedComponentChanged(
                            resolution is VehicleComponentTapSingle
                                ? resolution.occurrence.componentId
                                : null,
                          );
                        },
                        onTapCancel: () => onPressedComponentChanged(null),
                        onTapUp: (details) {
                          onPressedComponentChanged(null);
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
                              candidateIds,
                              existingFindings
                                  .where(
                                    (finding) =>
                                        finding.componentId ==
                                        occurrence.componentId,
                                  )
                                  .toList(growable: false),
                            ),
                            onTap: () => onSelected(occurrence.componentId),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    for (final occurrence in geometryView.occurrences)
                      if (existingFindings.any(
                        (finding) =>
                            finding.componentId == occurrence.componentId,
                      ))
                        for (
                          var index = 0;
                          index <
                              existingFindings
                                  .where(
                                    (finding) =>
                                        finding.componentId ==
                                        occurrence.componentId,
                                  )
                                  .length;
                          index++
                        )
                          _existingBadge(
                            context,
                            transform,
                            occurrence,
                            existingFindings
                                .where(
                                  (finding) =>
                                      finding.componentId ==
                                      occurrence.componentId,
                                )
                                .toList(growable: false),
                            index,
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

  Widget _existingBadge(
    BuildContext context,
    VehicleComponentGeometryTransform transform,
    VehicleComponentOccurrence occurrence,
    List<VehicleComponentExistingFinding> findings,
    int index,
  ) {
    final bounds = transform.toLocalBounds(occurrence.visualPath.getBounds());
    final finding = findings[index];
    final confirmed = finding.statusLabel == 'Confirmed';
    return Positioned(
      left: (bounds.right - 18 + index * 22).clamp(
        0.0,
        transform.localSize.width - 36,
      ),
      top: (bounds.top - 8 + index * 8).clamp(
        0.0,
        transform.localSize.height - 36,
      ),
      child: Semantics(
        button: true,
        label:
            'Existing finding ${index + 1} of ${findings.length}: ${finding.statusLabel.toLowerCase()} on ${VehicleComponentCatalog.byId(occurrence.componentId).label}. Show context.',
        child: InkWell(
          key: Key(
            'existing-finding-badge-${occurrence.componentId.wireValue}-${finding.id}',
          ),
          customBorder: const CircleBorder(),
          onTap: onExistingFindingSelected == null
              ? null
              : () => onExistingFindingSelected!(finding),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: confirmed ? 2 : 1.5,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                decoration: confirmed
                    ? TextDecoration.none
                    : TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
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
    required this.previousSelectedId,
    required this.selectionProgress,
    required this.suggestedId,
    required this.candidateIds,
    required this.pressedComponentId,
    required this.existingFindings,
    required this.colorScheme,
  });

  final VehicleComponentGeometry geometry;
  final VehicleComponentGeometryView view;
  final VehicleComponentGeometryTransform transform;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? previousSelectedId;
  final double selectionProgress;
  final VehicleComponentId? suggestedId;
  final List<VehicleComponentId> candidateIds;
  final VehicleComponentId? pressedComponentId;
  final List<VehicleComponentExistingFinding> existingFindings;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    transform.applyTo(canvas);
    final silhouetteBounds = view.silhouettePath.getBounds();
    canvas.drawShadow(
      view.silhouettePath,
      Colors.black.withValues(alpha: .28),
      8 / transform.scale,
      false,
    );
    canvas.drawPath(
      view.silhouettePath,
      Paint()
        ..shader = ui.Gradient.linear(
          silhouetteBounds.topLeft,
          silhouetteBounds.bottomRight,
          [colorScheme.surfaceContainerHighest, colorScheme.surface],
        ),
    );
    canvas.drawPath(
      view.silhouettePath,
      Paint()
        ..color = colorScheme.primary.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / transform.scale,
    );
    for (final decorativePath in view.decorativePaths) {
      final isGlass =
          decorativePath.id.toLowerCase().contains('glass') ||
          decorativePath.id.toLowerCase().contains('window');
      if (isGlass) {
        final bounds = decorativePath.path.getBounds();
        canvas.drawPath(
          decorativePath.path,
          Paint()
            ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [
              colorScheme.tertiary.withValues(alpha: .22),
              colorScheme.surface.withValues(alpha: .08),
            ]),
        );
      }
      canvas.drawPath(
        decorativePath.path,
        Paint()
          ..color =
              (isGlass ? colorScheme.tertiary : colorScheme.outlineVariant)
                  .withValues(alpha: isGlass ? .62 : .78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / transform.scale,
      );
    }
    for (final occurrence in view.occurrences) {
      final treatment = _selectionTreatment(occurrence.componentId);
      final pressed = occurrence.componentId == pressedComponentId;
      final existing = existingFindings.any(
        (finding) => finding.componentId == occurrence.componentId,
      );
      canvas.drawPath(
        occurrence.visualPath,
        Paint()
          ..color = Color.lerp(
            existing
                ? colorScheme.surfaceContainerLow.withValues(alpha: .9)
                : colorScheme.surfaceContainerHighest.withValues(alpha: .78),
            colorScheme.primary.withValues(alpha: .30),
            treatment,
          )!,
      );
      if (pressed) {
        canvas.drawPath(
          occurrence.visualPath,
          Paint()
            ..color = colorScheme.onSurface.withValues(alpha: .13)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 / transform.scale,
        );
      }
      canvas.drawPath(
        occurrence.visualPath,
        Paint()
          ..color = Color.lerp(
            existing ? colorScheme.outline : colorScheme.outlineVariant,
            colorScheme.primary,
            treatment,
          )!
          ..style = PaintingStyle.stroke
          ..strokeWidth = ui.lerpDouble(1.5, 4, treatment)! / transform.scale,
      );
      if (treatment > 0) {
        _drawCheckmark(canvas, occurrence.visualPath.getBounds(), treatment);
      }
      if (selectedId == null && occurrence.componentId == suggestedId) {
        _drawSuggestedMarker(canvas, occurrence.visualPath.getBounds());
      }
      if (selectedId == null) {
        final candidateIndex = candidateIds.indexOf(occurrence.componentId);
        if (candidateIndex >= 0) {
          _drawCandidateMarker(
            canvas,
            occurrence.visualPath.getBounds(),
            candidateIndex + 1,
          );
        }
      }
    }
    canvas.restore();
  }

  double _selectionTreatment(VehicleComponentId componentId) {
    if (selectedId == componentId) return selectionProgress;
    if (previousSelectedId == componentId) return 1 - selectionProgress;
    return 0;
  }

  void _drawCheckmark(Canvas canvas, ui.Rect bounds, double treatment) {
    final center = bounds.center;
    final radius = 18 * treatment / transform.scale;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = colorScheme.primary.withValues(alpha: treatment),
    );
    final mark = Path()
      ..moveTo(center.dx - radius * .5, center.dy)
      ..lineTo(center.dx - radius * .12, center.dy + radius * .38)
      ..lineTo(center.dx + radius * .56, center.dy - radius * .4);
    canvas.drawPath(
      mark,
      Paint()
        ..color = colorScheme.onPrimary.withValues(alpha: treatment)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / transform.scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawSuggestedMarker(Canvas canvas, ui.Rect bounds) {
    _drawDashedRect(
      canvas,
      bounds.inflate(5 / transform.scale),
      colorScheme.tertiary,
      2.5 / transform.scale,
    );
    final center = ui.Offset(
      bounds.center.dx,
      bounds.top - 8 / transform.scale,
    );
    final radius = 6 / transform.scale;
    final diamond = ui.Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = colorScheme.tertiary);
  }

  void _drawCandidateMarker(Canvas canvas, ui.Rect bounds, int number) {
    _drawDashedRect(
      canvas,
      bounds.inflate(3 / transform.scale),
      colorScheme.secondary,
      2 / transform.scale,
    );
    final center = ui.Offset(
      bounds.left + 8 / transform.scale,
      bounds.top + 8 / transform.scale,
    );
    final radius = 9 / transform.scale;
    canvas.drawCircle(center, radius, Paint()..color = colorScheme.secondary);
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: colorScheme.onSecondary,
          fontSize: 11 / transform.scale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - ui.Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawDashedRect(
    Canvas canvas,
    ui.Rect rect,
    ui.Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 7.0;
    const gap = 4.0;
    final sides = [
      [ui.Offset(rect.left, rect.top), ui.Offset(rect.right, rect.top)],
      [ui.Offset(rect.right, rect.top), ui.Offset(rect.right, rect.bottom)],
      [ui.Offset(rect.right, rect.bottom), ui.Offset(rect.left, rect.bottom)],
      [ui.Offset(rect.left, rect.bottom), ui.Offset(rect.left, rect.top)],
    ];
    for (final side in sides) {
      final start = side[0];
      final end = side[1];
      final delta = end - start;
      final length = delta.distance;
      final unit = delta / length;
      for (var offset = 0.0; offset < length; offset += dash + gap) {
        final from = start + unit * offset;
        final to = start + unit * math.min(offset + dash, length);
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VehicleComponentPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.view != view ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.previousSelectedId != previousSelectedId ||
      oldDelegate.selectionProgress != selectionProgress ||
      oldDelegate.suggestedId != suggestedId ||
      oldDelegate.candidateIds != candidateIds ||
      oldDelegate.pressedComponentId != pressedComponentId ||
      oldDelegate.existingFindings != existingFindings ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.transform.localSize != transform.localSize;
}

String _semanticLabel(
  VehicleComponentId componentId,
  VehicleComponentId? selectedId,
  VehicleComponentId? suggestedId,
  List<VehicleComponentId> candidateIds,
  List<VehicleComponentExistingFinding> existingFindings,
) {
  final state = <String>[];
  if (componentId == selectedId) state.add('Selected');
  if (componentId == suggestedId) state.add('Suggested');
  final candidateIndex = candidateIds.indexOf(componentId);
  if (candidateIndex >= 0) state.add('Possible match ${candidateIndex + 1}');
  final existing = existingFindings
      .where((finding) => finding.componentId == componentId)
      .toList(growable: false);
  if (existing.isNotEmpty) {
    final confirmed = existing
        .where((finding) => finding.statusLabel == 'Confirmed')
        .length;
    final proposed = existing.length - confirmed;
    final breakdown = <String>[
      if (confirmed > 0) '$confirmed confirmed',
      if (proposed > 0) '$proposed proposed',
    ].join(', ');
    state.add(
      '${existing.length} existing finding${existing.length == 1 ? '' : 's'}, $breakdown',
    );
  }
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
