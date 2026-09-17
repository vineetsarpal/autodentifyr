import 'dart:convert';
import 'dart:io';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleComponentGeometry', () {
    test(
      'loads the versioned contract with complete catalog coverage',
      () async {
        final geometry = VehicleComponentGeometry.fromJsonString(
          await File(
            'assets/vehicle_components/vehicle_component_geometry.v1.json',
          ).readAsString(),
        );

        expect(geometry.contractVersion, '1.0.0');
        expect(
          geometry.occurrences,
          hasLength(VehicleComponentCatalog.all.length),
        );
        expect(
          geometry.view(VehicleView.front).occurrences.first.componentId,
          VehicleComponentId.frontBumper,
        );
        expect(
          geometry
              .view(VehicleView.top)
              .decorativePaths
              .singleWhere((path) => path.id == 'top-left-wheel')
              .pathData,
          contains('Z M'),
        );
      },
    );

    test(
      'prefers a visual-path match over a neighboring hit-only match',
      () async {
        final geometry = await _loadGeometry();

        final resolution = geometry.resolveTap(
          VehicleView.front,
          const VehicleComponentPoint(.21, .6833),
        );

        expect(resolution, isA<VehicleComponentTapSingle>());
        expect(
          (resolution as VehicleComponentTapSingle).occurrence.componentId,
          VehicleComponentId.leftHeadlight,
        );
      },
    );

    test(
      'returns nearby overlapping hit targets as an ordered ambiguity',
      () async {
        final geometry = await _loadGeometry();

        final resolution = geometry.resolveTap(
          VehicleView.front,
          const VehicleComponentPoint(.3, .15),
        );

        expect(resolution, isA<VehicleComponentTapAmbiguous>());
        final ambiguity = resolution as VehicleComponentTapAmbiguous;
        expect(ambiguity.occurrences, hasLength(2));
        expect(
          ambiguity.occurrences.map((occurrence) => occurrence.componentId),
          [
            VehicleComponentId.leftFrontFender,
            VehicleComponentId.frontWindscreen,
          ],
        );
        expect(ambiguity.hasMoreCandidates, isFalse);
      },
    );

    test(
      'limits a dense overlap to three candidates with browse-all signal',
      () async {
        final source =
            jsonDecode(
                  await File(
                    'assets/vehicle_components/vehicle_component_geometry.v1.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final front = (source['views'] as List<Object?>)
            .cast<Map<String, dynamic>>()
            .singleWhere((view) => view['id'] == 'front');
        for (final occurrence
            in (front['occurrences'] as List<Object?>)
                .take(4)
                .cast<Map<String, dynamic>>()) {
          occurrence['hitPath'] = 'M0 0 L1000 0 L1000 600 L0 600 Z';
        }
        final geometry = VehicleComponentGeometry.fromJsonString(
          jsonEncode(source),
        );

        final resolution = geometry.resolveTap(
          VehicleView.front,
          const VehicleComponentPoint(.01, .01),
        );

        expect(resolution, isA<VehicleComponentTapAmbiguous>());
        final ambiguity = resolution as VehicleComponentTapAmbiguous;
        expect(ambiguity.occurrences, hasLength(3));
        expect(ambiguity.hasMoreCandidates, isTrue);
      },
    );
  });
}

Future<VehicleComponentGeometry> _loadGeometry() async =>
    VehicleComponentGeometry.fromJsonString(
      await File(
        'assets/vehicle_components/vehicle_component_geometry.v1.json',
      ).readAsString(),
    );
