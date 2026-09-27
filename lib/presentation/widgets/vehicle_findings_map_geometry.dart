import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../models/vehicle_component.dart';

/// A vehicle part path and its semantic/touch anchor in the viewBox.
class VehicleMapRegion {
  const VehicleMapRegion(this.componentId, this.path, {required this.anchor});

  final VehicleComponentId componentId;
  final Path path;
  final Offset anchor;
}

/// The exact component paths and non-interactive details for one fixed view.
class VehicleMapGeometry {
  const VehicleMapGeometry(this.size, this.parts, this.details);

  final Size size;
  final List<VehicleMapRegion> parts;
  final List<Path> details;

  factory VehicleMapGeometry.forView(VehicleView view) => switch (view) {
    VehicleView.top => _topGeometry(),
    VehicleView.front => _endGeometry(false),
    VehicleView.rear => _endGeometry(true),
    VehicleView.left => _sideGeometry(false),
    VehicleView.right => _sideGeometry(true),
  };
}

/// Shared fit transform for painting, pointer conversion, and semantics.
class VehicleMapTransform {
  VehicleMapTransform(this.source, this.target)
    : scale = math.min(
        target.width / source.width,
        target.height / source.height,
      ),
      offset = Offset(
        (target.width -
                source.width *
                    math.min(
                      target.width / source.width,
                      target.height / source.height,
                    )) /
            2,
        (target.height -
                source.height *
                    math.min(
                      target.width / source.width,
                      target.height / source.height,
                    )) /
            2,
      );

  final Size source;
  final Size target;
  final double scale;
  final Offset offset;

  Offset local(Offset point) => point * scale + offset;
  Offset sourcePoint(Offset point) => (point - offset) / scale;
  Rect bounds(Rect rect) =>
      Rect.fromPoints(local(rect.topLeft), local(rect.bottomRight));

  void apply(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
  }
}

/// Paints approved Paper line art, component outlines, selected regions,
/// finding counts, and accessible component actions.
class VehicleFindingsMapGeometry extends CustomPainter {
  const VehicleFindingsMapGeometry({
    required this.view,
    required this.selectedComponent,
    required this.findingCounts,
    required this.onComponentSelected,
    required this.ink,
    required this.detail,
    required this.paper,
  });

  final VehicleView view;
  final VehicleComponentId? selectedComponent;
  final Map<VehicleComponentId, int> findingCounts;
  final ValueChanged<VehicleComponentId> onComponentSelected;
  final Color ink;
  final Color detail;
  final Color paper;

  VehicleMapGeometry get geometry => VehicleMapGeometry.forView(view);

  @override
  void paint(Canvas canvas, Size size) {
    final model = geometry;
    final transform = VehicleMapTransform(model.size, size);
    canvas.save();
    transform.apply(canvas);

    final detailPaint = Paint()
      ..color = detail
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final part in model.parts) {
      final selected = part.componentId == selectedComponent;
      if (selected) {
        final halo = Paint()
          ..color = paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(part.path, halo);
        final focus = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(part.path, focus);
        final inner = Paint()
          ..color = paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(part.path, inner);
      } else {
        final fill = Paint()
          ..color = ink.withValues(alpha: .025)
          ..style = PaintingStyle.fill;
        canvas.drawPath(part.path, fill);
        canvas.drawPath(part.path, detailPaint);
      }
    }
    for (final path in model.details) {
      canvas.drawPath(path, detailPaint);
    }
    _paintFindingMarkers(canvas, model.parts, ink, paper);
    canvas.restore();
  }

  void _paintFindingMarkers(
    Canvas canvas,
    List<VehicleMapRegion> parts,
    Color markerColor,
    Color markerTextColor,
  ) {
    for (final part in parts) {
      final count = findingCounts[part.componentId] ?? 0;
      if (count == 0) continue;
      final center = part.anchor;
      const radius = 12.0;
      canvas.drawCircle(center, radius, Paint()..color = markerTextColor);
      canvas.drawCircle(
        center,
        radius - 1,
        Paint()
          ..color = markerColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            color: markerColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final model = geometry;
    final transform = VehicleMapTransform(model.size, size);
    return [
      for (final part in model.parts)
        CustomPainterSemantics(
          rect: _minimumTouchBounds(
            transform.bounds(part.path.getBounds()),
            size,
          ).intersect(Offset.zero & size),
          properties: SemanticsProperties(
            button: true,
            selected: part.componentId == selectedComponent,
            textDirection: TextDirection.ltr,
            label: _componentSemanticLabel(part.componentId),
            onTap: () => onComponentSelected(part.componentId),
          ),
        ),
    ];
  };

  String _componentSemanticLabel(VehicleComponentId id) {
    final label = VehicleComponentCatalog.byId(id).label;
    final count = findingCounts[id] ?? 0;
    return '$label vehicle component${count == 0 ? '' : ', $count findings'}';
  }

  @override
  bool shouldRepaint(VehicleFindingsMapGeometry oldDelegate) =>
      view != oldDelegate.view ||
      selectedComponent != oldDelegate.selectedComponent ||
      !mapEquals(findingCounts, oldDelegate.findingCounts) ||
      ink != oldDelegate.ink ||
      detail != oldDelegate.detail ||
      paper != oldDelegate.paper ||
      onComponentSelected != oldDelegate.onComponentSelected;

  @override
  bool shouldRebuildSemantics(VehicleFindingsMapGeometry oldDelegate) =>
      shouldRepaint(oldDelegate);
}

/// Exact path hit takes priority. Small/missed shapes receive an expanded
/// 44-pixel touch bound; overlapping expanded targets resolve to nearest anchor.
VehicleComponentId? hitTestVehicleMap(
  VehicleView view,
  Size target,
  Offset localPosition, {
  double minimumTouchSize = 44,
}) {
  final model = VehicleMapGeometry.forView(view);
  final transform = VehicleMapTransform(model.size, target);
  final sourcePosition = transform.sourcePoint(localPosition);
  final exact = model.parts
      .where((part) => part.path.contains(sourcePosition))
      .toList();
  final candidates = exact.isNotEmpty
      ? exact
      : model.parts
            .where(
              (part) => _minimumTouchBounds(
                transform.bounds(part.path.getBounds()),
                target,
                minimumTouchSize,
              ).contains(localPosition),
            )
            .toList();
  if (candidates.isEmpty) return null;
  candidates.sort(
    (a, b) => (transform.local(a.anchor) - localPosition).distanceSquared
        .compareTo((transform.local(b.anchor) - localPosition).distanceSquared),
  );
  return candidates.first.componentId;
}

Rect _minimumTouchBounds(Rect rect, Size canvas, [double minimum = 44]) {
  final width = math.max(rect.width, minimum);
  final height = math.max(rect.height, minimum);
  return Rect.fromCenter(
    center: rect.center,
    width: math.min(width, canvas.width),
    height: math.min(height, canvas.height),
  );
}

Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
Path box(double x, double y, double w, double h, [double radius = 0]) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(radius)),
  );
Path line(double x, double y, double x2, double y2) => Path()
  ..moveTo(x, y)
  ..lineTo(x2, y2);
Path poly(List<double> points) => polygon([
  for (var i = 0; i < points.length; i += 2) Offset(points[i], points[i + 1]),
]);

VehicleMapGeometry _topGeometry() {
  const ids = VehicleComponentId.values;
  final parts = <VehicleMapRegion>[];
  void add(VehicleComponentId component, Path path) => parts.add(
    VehicleMapRegion(component, path, anchor: path.getBounds().center),
  );
  add(
    VehicleComponentId.frontBumper,
    Path()
      ..moveTo(100, 76)
      ..cubicTo(125, 42, 275, 42, 300, 76)
      ..lineTo(298, 97)
      ..quadraticBezierTo(200, 72, 102, 97)
      ..close(),
  );
  add(
    VehicleComponentId.hood,
    Path()
      ..moveTo(115, 104)
      ..quadraticBezierTo(200, 83, 285, 104)
      ..lineTo(276, 223)
      ..quadraticBezierTo(200, 202, 124, 223)
      ..close(),
  );
  add(
    VehicleComponentId.frontWindscreen,
    poly([124, 230, 276, 230, 264, 284, 136, 284]),
  );
  add(VehicleComponentId.roof, box(136, 292, 128, 163, 17));
  add(
    VehicleComponentId.rearWindscreen,
    poly([136, 463, 264, 463, 279, 511, 121, 511]),
  );
  add(
    VehicleComponentId.trunkLid,
    Path()
      ..moveTo(121, 519)
      ..lineTo(279, 519)
      ..lineTo(289, 604)
      ..quadraticBezierTo(200, 624, 111, 604)
      ..close(),
  );
  add(VehicleComponentId.tailgate, box(151, 540, 98, 52, 8));
  add(
    VehicleComponentId.rearBumper,
    Path()
      ..moveTo(103, 614)
      ..quadraticBezierTo(200, 641, 297, 614)
      ..lineTo(298, 638)
      ..quadraticBezierTo(200, 674, 102, 638)
      ..close(),
  );
  for (final left in [true, false]) {
    Path reflect(Path path) => left
        ? path
        : path.transform(
            Float64List.fromList([
              -1,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              1,
              0,
              400,
              0,
              0,
              1,
            ]),
          );
    VehicleComponentId side(String suffix) => ids.firstWhere(
      (id) => id.wireValue == '${left ? 'left' : 'right'}_$suffix',
    );
    void addSide(String suffix, Path path) => add(side(suffix), reflect(path));
    addSide(
      'front_fender',
      poly([100, 104, 109, 104, 116, 224, 99, 258, 84, 245, 86, 155]),
    );
    addSide(
      'front_door',
      poly([98, 265, 127, 289, 127, 373, 84, 373, 84, 279]),
    );
    addSide(
      'rear_door',
      poly([84, 381, 127, 381, 128, 456, 104, 505, 85, 484]),
    );
    addSide(
      'rear_quarter_panel',
      poly([85, 492, 102, 513, 103, 608, 91, 607, 82, 547]),
    );
    addSide('mirror', box(54, 260, 26, 32, 7));
    addSide('headlight', poly([98, 80, 124, 77, 121, 94, 96, 100]));
    addSide('taillight', poly([93, 604, 114, 609, 120, 631, 96, 625]));
    addSide('running_board', box(61, 306, 18, 184, 5));
  }
  return VehicleMapGeometry(const Size(400, 720), parts, [
    box(69, 148, 10, 74, 4),
    box(321, 148, 10, 74, 4),
    box(69, 524, 10, 74, 4),
    box(321, 524, 10, 74, 4),
    line(111, 337, 111, 355),
    line(111, 421, 111, 439),
    line(289, 337, 289, 355),
    line(289, 421, 289, 439),
  ]);
}

VehicleMapGeometry _sideGeometry(bool right) {
  VehicleComponentId side(String suffix) =>
      VehicleComponentId.values.firstWhere(
        (id) => id.wireValue == '${right ? 'right' : 'left'}_$suffix',
      );
  final parts = <VehicleMapRegion>[
    VehicleMapRegion(
      side('front_fender'),
      Path()
        ..moveTo(93, 243)
        ..lineTo(249, 219)
        ..lineTo(279, 224)
        ..lineTo(264, 349)
        ..lineTo(243, 349)
        ..cubicTo(243, 256, 130, 256, 130, 349)
        ..lineTo(87, 349)
        ..close(),
      anchor: const Offset(160, 261),
    ),
    VehicleMapRegion(
      side('front_door'),
      poly([287, 222, 350, 140, 443, 137, 443, 350, 272, 350]),
      anchor: const Offset(360, 280),
    ),
    VehicleMapRegion(
      side('rear_door'),
      poly([452, 137, 543, 146, 604, 223, 601, 350, 452, 350]),
      anchor: const Offset(529, 280),
    ),
    VehicleMapRegion(
      side('rear_quarter_panel'),
      Path()
        ..moveTo(550, 146)
        ..quadraticBezierTo(580, 145, 625, 195)
        ..lineTo(671, 224)
        ..lineTo(768, 245)
        ..lineTo(790, 349)
        ..lineTo(744, 349)
        ..cubicTo(744, 256, 630, 256, 630, 349)
        ..lineTo(610, 349)
        ..lineTo(612, 224)
        ..close(),
      anchor: const Offset(687, 263),
    ),
    VehicleMapRegion(
      side('running_board'),
      box(274, 359, 330, 13, 3),
      anchor: const Offset(439, 365),
    ),
    VehicleMapRegion(
      side('mirror'),
      box(270, 212, 40, 23, 8),
      anchor: const Offset(290, 223),
    ),
    VehicleMapRegion(
      VehicleComponentId.frontBumper,
      box(67, 291, 20, 56, 6),
      anchor: const Offset(77, 319),
    ),
    VehicleMapRegion(
      VehicleComponentId.rearBumper,
      box(789, 285, 24, 62, 6),
      anchor: const Offset(801, 316),
    ),
  ];
  final details = [
    poly([307, 217, 358, 150, 430, 147, 430, 217]),
    poly([465, 147, 538, 157, 585, 217, 465, 217]),
    line(398, 238, 424, 238),
    line(559, 238, 585, 238),
    Path()..addOval(const Rect.fromLTWH(141, 294, 91, 91)),
    Path()..addOval(const Rect.fromLTWH(159, 312, 55, 55)),
    Path()..addOval(const Rect.fromLTWH(641, 294, 91, 91)),
    Path()..addOval(const Rect.fromLTWH(659, 312, 55, 55)),
    Path()
      ..moveTo(93, 240)
      ..lineTo(252, 211)
      ..lineTo(338, 132)
      ..quadraticBezierTo(370, 120, 443, 125)
      ..lineTo(543, 134)
      ..quadraticBezierTo(590, 138, 631, 188),
  ];
  if (!right) return VehicleMapGeometry(const Size(880, 450), parts, details);
  final mirror = Float64List.fromList([
    -1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    880,
    0,
    0,
    1,
  ]);
  return VehicleMapGeometry(
    const Size(880, 450),
    [
      for (final part in parts)
        VehicleMapRegion(
          part.componentId,
          part.path.transform(mirror),
          anchor: Offset(880 - part.anchor.dx, part.anchor.dy),
        ),
    ],
    [for (final path in details) path.transform(mirror)],
  );
}

VehicleMapGeometry _endGeometry(bool rear) {
  // Looking at the front, vehicle-left is on the viewer's right.
  final leftX = rear ? 142.0 : 508.0;
  final rightX = rear ? 508.0 : 142.0;
  VehicleMapRegion part(VehicleComponentId id, Path path) =>
      VehicleMapRegion(id, path, anchor: path.getBounds().center);
  final parts = <VehicleMapRegion>[
    part(
      rear
          ? VehicleComponentId.rearWindscreen
          : VehicleComponentId.frontWindscreen,
      Path()
        ..moveTo(237, 113)
        ..quadraticBezierTo(400, 92, 563, 113)
        ..lineTo(601, 202)
        ..lineTo(199, 202)
        ..close(),
    ),
    part(
      rear ? VehicleComponentId.trunkLid : VehicleComponentId.hood,
      Path()
        ..moveTo(198, 211)
        ..lineTo(602, 211)
        ..lineTo(646, 262)
        ..quadraticBezierTo(400, 278, 154, 262)
        ..close(),
    ),
    part(
      rear ? VehicleComponentId.rearBumper : VehicleComponentId.frontBumper,
      box(136, 324, 528, 61, 17),
    ),
    part(
      rear
          ? VehicleComponentId.leftTaillight
          : VehicleComponentId.leftHeadlight,
      box(leftX, 276, 150, 39, 10),
    ),
    part(
      rear
          ? VehicleComponentId.rightTaillight
          : VehicleComponentId.rightHeadlight,
      box(rightX, 276, 150, 39, 10),
    ),
    part(VehicleComponentId.leftMirror, box(rear ? 139 : 619, 180, 42, 27, 8)),
    part(VehicleComponentId.rightMirror, box(rear ? 619 : 139, 180, 42, 27, 8)),
    if (rear) part(VehicleComponentId.tailgate, box(304, 279, 192, 36, 4)),
  ];
  return VehicleMapGeometry(const Size(800, 470), parts, [
    Path()
      ..moveTo(134, 337)
      ..lineTo(144, 270)
      ..lineTo(190, 201)
      ..lineTo(225, 106)
      ..quadraticBezierTo(400, 72, 575, 106)
      ..lineTo(610, 201)
      ..lineTo(656, 270)
      ..lineTo(666, 337),
    box(146, 388, 47, 20, 6),
    box(607, 388, 47, 20, 6),
    if (!rear) box(313, 286, 174, 28, 7),
    box(349, 340, 102, 26, 3),
  ]);
}

/// All canonical component identities represented by at least one approved
/// view path. Multiple visible occurrences map to the same canonical ID.
Set<VehicleComponentId> vehicleMapCoveredComponents() => {
  for (final view in VehicleView.values)
    for (final region in VehicleMapGeometry.forView(view).parts)
      region.componentId,
};

/// Every canonical component is represented in the unfolded top schematic.
Set<VehicleComponentId> vehicleTopMapCoveredComponents() => {
  for (final region in VehicleMapGeometry.forView(VehicleView.top).parts)
    region.componentId,
};

/// Returns exact or expanded touch candidates without guessing between them.
List<VehicleComponentId> hitTestVehicleMapCandidates(
  VehicleView view,
  Size target,
  Offset localPosition, {
  double minimumTouchSize = 44,
}) {
  final model = VehicleMapGeometry.forView(view);
  final transform = VehicleMapTransform(model.size, target);
  final sourcePosition = transform.sourcePoint(localPosition);
  final exact = model.parts
      .where((part) => part.path.contains(sourcePosition))
      .toList();
  final candidates = exact.isNotEmpty
      ? exact
      : model.parts
            .where(
              (part) => _minimumTouchBounds(
                transform.bounds(part.path.getBounds()),
                target,
                minimumTouchSize,
              ).contains(localPosition),
            )
            .toList();
  candidates.sort(
    (a, b) => (transform.local(a.anchor) - localPosition).distanceSquared
        .compareTo((transform.local(b.anchor) - localPosition).distanceSquared),
  );
  return candidates.map((part) => part.componentId).toSet().toList();
}

/// Exact geometry regions for the selected fixed view.
List<VehicleMapRegion> vehicleMapRegions(VehicleView view) =>
    VehicleMapGeometry.forView(view).parts;
