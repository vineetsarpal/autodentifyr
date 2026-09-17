import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:autodentifyr/models/vehicle_component.dart';

/// A normalized point in the geometry contract's unit coordinate space.
///
/// Both values are fractions of the contract canvas: `0..1` from its
/// top-left corner. Renderers should apply their shared transform only after
/// resolving a tap into this coordinate system.
class VehicleComponentPoint {
  const VehicleComponentPoint(this.x, this.y)
    : assert(x >= 0 && x <= 1),
      assert(y >= 0 && y <= 1);

  final double x;
  final double y;
}

/// The shared aspect-fit mapping between a rendered diagram and its contract.
///
/// Painting, semantic bounds, and local touch conversion must all use this
/// transform so a tap resolves against exactly the shape the Appraiser sees.
class VehicleComponentGeometryTransform {
  VehicleComponentGeometryTransform({
    required this.geometry,
    required this.localSize,
  }) : scale = math.min(
         localSize.width / geometry.width,
         localSize.height / geometry.height,
       ),
       contentBounds = _contentBounds(geometry, localSize);

  final VehicleComponentGeometry geometry;
  final ui.Size localSize;
  final double scale;
  final ui.Rect contentBounds;

  static ui.Rect _contentBounds(
    VehicleComponentGeometry geometry,
    ui.Size localSize,
  ) {
    final scale = math.min(
      localSize.width / geometry.width,
      localSize.height / geometry.height,
    );
    final width = geometry.width * scale;
    final height = geometry.height * scale;
    return ui.Rect.fromLTWH(
      (localSize.width - width) / 2,
      (localSize.height - height) / 2,
      width,
      height,
    );
  }

  void applyTo(ui.Canvas canvas) {
    canvas.translate(contentBounds.left, contentBounds.top);
    canvas.scale(scale);
  }

  VehicleComponentPoint? toNormalized(ui.Offset localPosition) {
    if (!contentBounds.contains(localPosition)) return null;
    return VehicleComponentPoint(
      (localPosition.dx - contentBounds.left) / contentBounds.width,
      (localPosition.dy - contentBounds.top) / contentBounds.height,
    );
  }

  ui.Rect toLocalBounds(ui.Rect contractBounds, {double minimumSize = 0}) {
    final bounds = ui.Rect.fromLTRB(
      contentBounds.left + contractBounds.left * scale,
      contentBounds.top + contractBounds.top * scale,
      contentBounds.left + contractBounds.right * scale,
      contentBounds.top + contractBounds.bottom * scale,
    );
    if (minimumSize == 0 ||
        (bounds.width >= minimumSize && bounds.height >= minimumSize)) {
      return bounds;
    }
    return ui.Rect.fromCenter(
      center: bounds.center,
      width: math.max(bounds.width, minimumSize),
      height: math.max(bounds.height, minimumSize),
    );
  }
}

/// Parsed and validated versioned geometry for the component picker.
class VehicleComponentGeometry {
  VehicleComponentGeometry._({
    required this.contractVersion,
    required this.assetId,
    required this.width,
    required this.height,
    required Map<VehicleView, VehicleComponentGeometryView> views,
  }) : _views = Map.unmodifiable(views);

  static const assetPath =
      'assets/vehicle_components/vehicle_component_geometry.v1.json';

  final String contractVersion;
  final String assetId;
  final double width;
  final double height;
  final Map<VehicleView, VehicleComponentGeometryView> _views;

  Iterable<VehicleComponentGeometryView> get views => _views.values;
  Iterable<VehicleComponentOccurrence> get occurrences =>
      _views.values.expand((view) => view.occurrences);

  VehicleComponentGeometryView view(VehicleView view) => _views[view]!;

  static Future<VehicleComponentGeometry> loadAsset([
    AssetBundle? bundle,
  ]) async => VehicleComponentGeometry.fromJsonString(
    await (bundle ?? rootBundle).loadString(assetPath),
  );

  factory VehicleComponentGeometry.fromJsonString(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, dynamic>) {
      throw const FormatException(
        'Vehicle component geometry must be an object.',
      );
    }
    final version = root['contractVersion'];
    if (version != '1.0.0') {
      throw FormatException(
        'Unsupported vehicle component geometry version: $version.',
      );
    }
    final assetId = root['assetId'];
    if (assetId != 'autodentifyr.vehicle-component-geometry') {
      throw const FormatException(
        'Unexpected vehicle component geometry asset ID.',
      );
    }
    final coordinateSystem = _object(
      root['coordinateSystem'],
      'coordinateSystem',
    );
    final width = _number(coordinateSystem['width'], 'coordinateSystem.width');
    final height = _number(
      coordinateSystem['height'],
      'coordinateSystem.height',
    );
    if (width <= 0 ||
        height <= 0 ||
        coordinateSystem['pathFormat'] != 'svg-path-data') {
      throw const FormatException(
        'Invalid vehicle component coordinate system.',
      );
    }
    final decodedViews = _list(root['views'], 'views');
    final views = <VehicleView, VehicleComponentGeometryView>{};
    final seenIds = <VehicleComponentId>{};
    for (final entry in decodedViews) {
      final decoded = _object(entry, 'view');
      final view = _viewFromId(decoded['id']);
      if (views.containsKey(view)) {
        throw FormatException('Duplicate geometry view: ${decoded['id']}.');
      }
      final composition = _object(decoded['composition'], 'composition');
      final silhouettePathData = _string(
        composition['silhouettePath'],
        'composition.silhouettePath',
      );
      final silhouettePath = _SvgPath.parse(silhouettePathData);
      final decorativePaths = <VehicleComponentDecorativePath>[];
      for (final rawDecorativePath in _list(
        composition['decorativePaths'],
        'composition.decorativePaths',
      )) {
        final decorativePath = _object(rawDecorativePath, 'decorative path');
        final id = _string(decorativePath['id'], 'decorativePath.id');
        final pathData = _string(decorativePath['path'], 'decorativePath.path');
        final parsedPath = _SvgPath.parse(pathData);
        decorativePaths.add(
          VehicleComponentDecorativePath(id, pathData, parsedPath.path),
        );
      }
      final occurrences = <VehicleComponentOccurrence>[];
      var expectedOrder = 1;
      for (final rawOccurrence in _list(
        decoded['occurrences'],
        'occurrences',
      )) {
        final occurrence = _object(rawOccurrence, 'occurrence');
        final componentId = VehicleComponentId.fromWire(
          _string(occurrence['componentId'], 'occurrence.componentId'),
        );
        if (!seenIds.add(componentId)) {
          throw FormatException(
            'Duplicate component geometry: ${componentId.wireValue}.',
          );
        }
        final order = occurrence['semanticsOrder'];
        if (order != expectedOrder) {
          throw FormatException(
            'Geometry semantics order must be consecutive in ${view.name}.',
          );
        }
        expectedOrder += 1;
        final visualPath = _SvgPath.parse(
          _string(occurrence['visualPath'], 'occurrence.visualPath'),
        );
        final hitPath = _SvgPath.parse(
          _string(occurrence['hitPath'], 'occurrence.hitPath'),
        );
        occurrences.add(
          VehicleComponentOccurrence._(
            componentId: componentId,
            visualPathData: visualPath.source,
            hitPathData: hitPath.source,
            semanticsOrder: order as int,
            visualPath: visualPath,
            hitPath: hitPath,
          ),
        );
      }
      views[view] = VehicleComponentGeometryView(
        view: view,
        silhouettePathData: silhouettePathData,
        silhouettePath: silhouettePath.path,
        decorativePaths: List.unmodifiable(decorativePaths),
        occurrences: List.unmodifiable(occurrences),
      );
    }
    if (views.length != VehicleView.values.length ||
        !VehicleView.values.every(views.containsKey) ||
        seenIds.length != VehicleComponentCatalog.all.length ||
        !VehicleComponentCatalog.all.every(
          (component) => seenIds.contains(component.id),
        )) {
      throw const FormatException(
        'Geometry must cover every current view and component exactly once.',
      );
    }
    for (final component in VehicleComponentCatalog.all) {
      final occurrence = views.values
          .expand((view) => view.occurrences)
          .singleWhere((item) => item.componentId == component.id);
      if (_occurrenceView(views, occurrence) != component.primaryView) {
        throw FormatException(
          'Geometry occurrence for ${component.id.wireValue} must be in its primary view.',
        );
      }
    }
    return VehicleComponentGeometry._(
      contractVersion: version as String,
      assetId: assetId as String,
      width: width,
      height: height,
      views: views,
    );
  }

  /// Resolves a normalized tap without relying on paint order or path bounds.
  VehicleComponentTapResolution resolveTap(
    VehicleView view,
    VehicleComponentPoint point,
  ) {
    final contractPoint = _Point(point.x * width, point.y * height);
    final occurrences = this.view(view).occurrences;
    var matches = occurrences
        .where((occurrence) => occurrence._visualPath.contains(contractPoint))
        .toList(growable: false);
    if (matches.isEmpty) {
      matches = occurrences
          .where((occurrence) => occurrence._hitPath.contains(contractPoint))
          .toList(growable: false);
    }
    if (matches.isEmpty) return const VehicleComponentTapMiss();
    matches = matches.toList()
      ..sort((left, right) {
        final distance = left._visualPath
            .distanceTo(contractPoint)
            .compareTo(right._visualPath.distanceTo(contractPoint));
        return distance != 0
            ? distance
            : left.semanticsOrder.compareTo(right.semanticsOrder);
      });
    if (matches.length == 1) return VehicleComponentTapSingle(matches.single);
    return VehicleComponentTapAmbiguous(
      matches.take(3).toList(growable: false),
      hasMoreCandidates: matches.length > 3,
    );
  }
}

VehicleView _occurrenceView(
  Map<VehicleView, VehicleComponentGeometryView> views,
  VehicleComponentOccurrence occurrence,
) => views.entries
    .singleWhere((entry) => entry.value.occurrences.contains(occurrence))
    .key;

class VehicleComponentGeometryView {
  const VehicleComponentGeometryView({
    required this.view,
    required this.silhouettePathData,
    required this.silhouettePath,
    required this.decorativePaths,
    required this.occurrences,
  });

  final VehicleView view;
  final String silhouettePathData;
  final ui.Path silhouettePath;
  final List<VehicleComponentDecorativePath> decorativePaths;
  final List<VehicleComponentOccurrence> occurrences;
}

class VehicleComponentDecorativePath {
  const VehicleComponentDecorativePath(this.id, this.pathData, this.path);

  final String id;
  final String pathData;
  final ui.Path path;
}

class VehicleComponentOccurrence {
  const VehicleComponentOccurrence._({
    required this.componentId,
    required this.visualPathData,
    required this.hitPathData,
    required this.semanticsOrder,
    required _SvgPath visualPath,
    required _SvgPath hitPath,
  }) : _visualPath = visualPath,
       _hitPath = hitPath;

  final VehicleComponentId componentId;
  final String visualPathData;
  final String hitPathData;
  final int semanticsOrder;
  ui.Path get visualPath => _visualPath.path;
  ui.Path get hitPath => _hitPath.path;
  ui.Rect get hitBounds => _hitPath.path.getBounds();
  final _SvgPath _visualPath;
  final _SvgPath _hitPath;
}

sealed class VehicleComponentTapResolution {
  const VehicleComponentTapResolution();
}

final class VehicleComponentTapMiss extends VehicleComponentTapResolution {
  const VehicleComponentTapMiss();
}

final class VehicleComponentTapSingle extends VehicleComponentTapResolution {
  const VehicleComponentTapSingle(this.occurrence);

  final VehicleComponentOccurrence occurrence;
}

final class VehicleComponentTapAmbiguous extends VehicleComponentTapResolution {
  const VehicleComponentTapAmbiguous(
    this.occurrences, {
    required this.hasMoreCandidates,
  });

  final List<VehicleComponentOccurrence> occurrences;
  final bool hasMoreCandidates;
}

Map<String, dynamic> _object(Object? value, String name) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$name must be an object.');
}

List<Object?> _list(Object? value, String name) {
  if (value is List<Object?>) return value;
  throw FormatException('$name must be an array.');
}

String _string(Object? value, String name) {
  if (value is String) return value;
  throw FormatException('$name must be a string.');
}

double _number(Object? value, String name) {
  if (value is num) return value.toDouble();
  throw FormatException('$name must be a number.');
}

VehicleView _viewFromId(Object? value) => switch (value) {
  'top' => VehicleView.top,
  'front' => VehicleView.front,
  'rear' => VehicleView.rear,
  'left' => VehicleView.left,
  'right' => VehicleView.right,
  _ => throw FormatException('Unknown vehicle geometry view: $value.'),
};

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

class _SvgPath {
  _SvgPath._(this.source, this._subpaths, this.path);

  final String source;
  final List<List<_Point>> _subpaths;
  final ui.Path path;

  static _SvgPath parse(String source) {
    final tokens = RegExp(r'[MLCZ]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    var index = 0;
    String? command;
    _Point? current;
    _Point? subpathStart;
    final subpaths = <List<_Point>>[];
    final path = ui.Path();
    List<_Point>? active;
    parseLoop:
    while (index < tokens.length) {
      final token = tokens[index];
      if (RegExp(r'^[MLCZ]$').hasMatch(token)) {
        command = token;
        index += 1;
      }
      switch (command) {
        case 'M':
          final point = _readPoint(tokens, index);
          index += 2;
          active = <_Point>[point];
          subpaths.add(active);
          path.moveTo(point.x, point.y);
          current = point;
          subpathStart = point;
          command = 'L';
          continue parseLoop;
        case 'L':
          if (current == null || active == null) {
            throw const FormatException('Line before move in SVG path.');
          }
          final point = _readPoint(tokens, index);
          index += 2;
          active.add(point);
          path.lineTo(point.x, point.y);
          current = point;
          continue parseLoop;
        case 'C':
          if (current == null || active == null) {
            throw const FormatException('Curve before move in SVG path.');
          }
          final controlOne = _readPoint(tokens, index);
          final controlTwo = _readPoint(tokens, index + 2);
          final end = _readPoint(tokens, index + 4);
          index += 6;
          for (var step = 1; step <= 16; step += 1) {
            active.add(_cubic(current, controlOne, controlTwo, end, step / 16));
          }
          path.cubicTo(
            controlOne.x,
            controlOne.y,
            controlTwo.x,
            controlTwo.y,
            end.x,
            end.y,
          );
          current = end;
          continue parseLoop;
        case 'Z':
          if (active == null || subpathStart == null) {
            throw const FormatException('Close before move in SVG path.');
          }
          active.add(subpathStart);
          path.close();
          current = subpathStart;
          command = null;
          continue parseLoop;
        case null:
          throw const FormatException('SVG path must begin with M.');
        default:
          throw FormatException('Unsupported SVG path command: $command.');
      }
    }
    if (subpaths.isEmpty) throw const FormatException('SVG path is empty.');
    return _SvgPath._(source, subpaths, path);
  }

  bool contains(_Point point) => _subpaths.fold(
    false,
    (inside, path) => inside ^ _containsPath(path, point),
  );

  double distanceTo(_Point point) {
    if (contains(point)) return 0;
    var closest = double.infinity;
    for (final path in _subpaths) {
      for (var index = 1; index < path.length; index += 1) {
        closest = math.min(
          closest,
          _distanceToSegment(point, path[index - 1], path[index]),
        );
      }
    }
    return closest;
  }
}

_Point _readPoint(List<String> tokens, int index) {
  if (index + 1 >= tokens.length) {
    throw const FormatException('Incomplete SVG point.');
  }
  return _Point(double.parse(tokens[index]), double.parse(tokens[index + 1]));
}

_Point _cubic(_Point start, _Point one, _Point two, _Point end, double t) {
  final inverse = 1 - t;
  return _Point(
    inverse * inverse * inverse * start.x +
        3 * inverse * inverse * t * one.x +
        3 * inverse * t * t * two.x +
        t * t * t * end.x,
    inverse * inverse * inverse * start.y +
        3 * inverse * inverse * t * one.y +
        3 * inverse * t * t * two.y +
        t * t * t * end.y,
  );
}

bool _containsPath(List<_Point> path, _Point point) {
  var inside = false;
  for (var index = 1; index < path.length; index += 1) {
    final one = path[index - 1];
    final two = path[index];
    final crosses = (one.y > point.y) != (two.y > point.y);
    if (crosses &&
        point.x <
            (two.x - one.x) * (point.y - one.y) / (two.y - one.y) + one.x) {
      inside = !inside;
    }
  }
  return inside;
}

double _distanceToSegment(_Point point, _Point one, _Point two) {
  final dx = two.x - one.x;
  final dy = two.y - one.y;
  final squaredLength = dx * dx + dy * dy;
  if (squaredLength == 0) {
    return math.sqrt(
      math.pow(point.x - one.x, 2) + math.pow(point.y - one.y, 2),
    );
  }
  final projection =
      (((point.x - one.x) * dx + (point.y - one.y) * dy) / squaredLength).clamp(
        0.0,
        1.0,
      );
  final x = one.x + projection * dx;
  final y = one.y + projection * dy;
  return math.sqrt(math.pow(point.x - x, 2) + math.pow(point.y - y, 2));
}
