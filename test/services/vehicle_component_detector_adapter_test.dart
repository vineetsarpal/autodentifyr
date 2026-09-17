import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleComponentDetectorAdapter', () {
    test('maps an unambiguous detector class to its canonical component', () {
      final result = VehicleComponentDetectorAdapter.resolve('bonnet-dent');

      expect(result, isA<ExactVehicleComponentDetectorResult>());
      expect(
        (result as ExactVehicleComponentDetectorResult).componentId,
        VehicleComponentId.hood,
      );
    });

    test(
      'retains all plausible canonical candidates for ambiguous classes',
      () {
        final result = VehicleComponentDetectorAdapter.resolve(
          'headlight-damage',
        );

        expect(result, isA<CandidateVehicleComponentDetectorResult>());
        expect(
          (result as CandidateVehicleComponentDetectorResult).componentIds,
          [VehicleComponentId.leftHeadlight, VehicleComponentId.rightHeadlight],
        );
      },
    );

    test('maps every remaining documented detector class explicitly', () {
      const exactMappings = {
        'front-windscreen-damage': VehicleComponentId.frontWindscreen,
        'rear-windscreen-damage': VehicleComponentId.rearWindscreen,
        'front-bumper-dent': VehicleComponentId.frontBumper,
        'rear-bumper-dent': VehicleComponentId.rearBumper,
        'roof-dent': VehicleComponentId.roof,
      };
      const candidateMappings = {
        'runningboard-damage': [
          VehicleComponentId.leftRunningBoard,
          VehicleComponentId.rightRunningBoard,
        ],
        'sidemirror-damage': [
          VehicleComponentId.leftMirror,
          VehicleComponentId.rightMirror,
        ],
        'taillight-damage': [
          VehicleComponentId.leftTaillight,
          VehicleComponentId.rightTaillight,
        ],
        'boot-dent': [VehicleComponentId.trunkLid, VehicleComponentId.tailgate],
        'doorouter-dent': [
          VehicleComponentId.leftFrontDoor,
          VehicleComponentId.leftRearDoor,
          VehicleComponentId.rightFrontDoor,
          VehicleComponentId.rightRearDoor,
        ],
        'fender-dent': [
          VehicleComponentId.leftFrontFender,
          VehicleComponentId.rightFrontFender,
        ],
        'quaterpanel-dent': [
          VehicleComponentId.leftRearQuarterPanel,
          VehicleComponentId.rightRearQuarterPanel,
        ],
      };

      for (final entry in exactMappings.entries) {
        final result = VehicleComponentDetectorAdapter.resolve(entry.key);
        expect(result, isA<ExactVehicleComponentDetectorResult>());
        expect(
          (result as ExactVehicleComponentDetectorResult).componentId,
          entry.value,
        );
      }
      for (final entry in candidateMappings.entries) {
        final result = VehicleComponentDetectorAdapter.resolve(entry.key);
        expect(result, isA<CandidateVehicleComponentDetectorResult>());
        expect(
          (result as CandidateVehicleComponentDetectorResult).componentIds,
          entry.value,
        );
      }
    });

    test(
      'does not guess for unsupported labels or corrected detector typos',
      () {
        for (final detectorClass in ['quarterpanel-dent', 'HEADLIGHT-DAMAGE']) {
          final result = VehicleComponentDetectorAdapter.resolve(detectorClass);

          expect(result, isA<UnknownVehicleComponentDetectorResult>());
          expect(
            (result as UnknownVehicleComponentDetectorResult).detectorClass,
            detectorClass,
          );
        }
      },
    );

    test('resolves repeated exact evidence to one canonical component', () {
      final result = VehicleComponentDetectorAdapter.resolveAll([
        'bonnet-dent',
        'bonnet-dent',
      ]);

      expect(result, isA<ExactVehicleComponentDetectorResult>());
      expect(
        (result as ExactVehicleComponentDetectorResult).componentId,
        VehicleComponentId.hood,
      );
    });

    test('deduplicates candidates in evidence order then adapter order', () {
      final result = VehicleComponentDetectorAdapter.resolveAll([
        'headlight-damage',
        'bonnet-dent',
        'headlight-damage',
        'taillight-damage',
      ]);

      expect(result, isA<CandidateVehicleComponentDetectorResult>());
      expect((result as CandidateVehicleComponentDetectorResult).componentIds, [
        VehicleComponentId.leftHeadlight,
        VehicleComponentId.rightHeadlight,
        VehicleComponentId.hood,
        VehicleComponentId.leftTaillight,
        VehicleComponentId.rightTaillight,
      ]);
    });

    test(
      'ignores unknown evidence without converting an exact match to a guess',
      () {
        final result = VehicleComponentDetectorAdapter.resolveAll([
          'not-a-model-class',
          'bonnet-dent',
        ]);

        expect(result, isA<ExactVehicleComponentDetectorResult>());
        expect(
          (result as ExactVehicleComponentDetectorResult).componentId,
          VehicleComponentId.hood,
        );
      },
    );

    test('returns unknown when no evidence has a documented mapping', () {
      final result = VehicleComponentDetectorAdapter.resolveAll([
        'not-a-model-class',
        'quarterpanel-dent',
      ]);

      expect(result, isA<UnknownVehicleComponentDetectorResult>());
    });
  });
}
