import 'dart:io';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/vehicle_component_picker_controller.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleComponentPickerController', () {
    test('opens an existing component selected in its primary view', () {
      final controller = VehicleComponentPickerController(
        existingId: VehicleComponentId.leftFrontDoor,
      );

      expect(controller.state.selectedId, VehicleComponentId.leftFrontDoor);
      expect(controller.state.view, VehicleView.left);
      expect(controller.state.suggestedId, isNull);
    });

    test('shows an exact suggestion without selecting it', () {
      final controller = VehicleComponentPickerController(
        detectorResult: const ExactVehicleComponentDetectorResult(
          'bonnet-dent',
          VehicleComponentId.hood,
        ),
      );

      expect(controller.state.selectedId, isNull);
      expect(controller.state.suggestedId, VehicleComponentId.hood);
      expect(controller.state.view, VehicleView.front);
      expect(controller.useSelection(), isNull);
    });

    test('starts candidate and manual pickers empty in the top view', () {
      final candidates = VehicleComponentPickerController(
        detectorResult: const CandidateVehicleComponentDetectorResult(
          'headlight-damage',
          [VehicleComponentId.leftHeadlight, VehicleComponentId.rightHeadlight],
        ),
      );
      final manual = VehicleComponentPickerController();

      expect(candidates.state.selectedId, isNull);
      expect(candidates.state.view, VehicleView.top);
      expect(candidates.state.candidateIds, [
        VehicleComponentId.leftHeadlight,
        VehicleComponentId.rightHeadlight,
      ]);
      expect(manual.state.selectedId, isNull);
      expect(manual.state.view, VehicleView.top);
    });

    test(
      'syncs a diagram selection to the catalog primary view and use result',
      () async {
        final controller = VehicleComponentPickerController();
        final geometry = VehicleComponentGeometry.fromJsonString(
          await File(
            'assets/vehicle_components/vehicle_component_geometry.v1.json',
          ).readAsString(),
        );

        controller.handleTap(
          geometry.resolveTap(
            VehicleView.front,
            const VehicleComponentPoint(.5, .7),
          ),
        );

        expect(controller.state.selectedId, VehicleComponentId.frontBumper);
        expect(controller.state.view, VehicleView.front);
        expect(
          controller.useSelection(),
          isA<VehicleComponentPickerAccepted>(),
        );
        expect(
          (controller.useSelection() as VehicleComponentPickerAccepted)
              .componentId,
          VehicleComponentId.frontBumper,
        );
      },
    );

    test('keeps selection while browsing and keeps alias search state', () {
      final controller = VehicleComponentPickerController();

      controller.selectFromList(VehicleComponentId.leftFrontDoor);
      controller.changeView(VehicleView.rear);
      controller.updateQuery('bonnet');

      expect(controller.state.selectedId, VehicleComponentId.leftFrontDoor);
      expect(controller.state.view, VehicleView.rear);
      expect(controller.state.query, 'bonnet');
      expect(
        controller.state.visibleComponents.map((component) => component.id),
        [VehicleComponentId.hood],
      );
    });

    test(
      'preserves an ambiguous tap for explicit Appraiser resolution',
      () async {
        final controller = VehicleComponentPickerController();
        final geometry = VehicleComponentGeometry.fromJsonString(
          await File(
            'assets/vehicle_components/vehicle_component_geometry.v1.json',
          ).readAsString(),
        );

        controller.handleTap(
          geometry.resolveTap(
            VehicleView.front,
            const VehicleComponentPoint(.3, .15),
          ),
        );

        expect(controller.state.selectedId, isNull);
        expect(controller.state.ambiguity!.candidateIds, [
          VehicleComponentId.leftFrontFender,
          VehicleComponentId.frontWindscreen,
        ]);
        controller.selectAmbiguousCandidate(VehicleComponentId.frontWindscreen);
        expect(controller.state.selectedId, VehicleComponentId.frontWindscreen);
        expect(controller.state.ambiguity, isNull);
      },
    );

    test('undo returns to its opening value and reselect is idempotent', () {
      final controller = VehicleComponentPickerController(
        existingId: VehicleComponentId.leftFrontDoor,
      );
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      controller.selectFromList(VehicleComponentId.rearBumper);
      controller.undo();
      controller.selectFromList(VehicleComponentId.leftFrontDoor);

      expect(controller.state.selectedId, VehicleComponentId.leftFrontDoor);
      expect(controller.state.view, VehicleView.left);
      expect(notifications, 2);
      expect(controller.cancel(), isA<VehicleComponentPickerCancelled>());
    });
  });
}
