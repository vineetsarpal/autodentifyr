import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleComponentCatalog', () {
    test('exposes the 24 canonical components in stable order', () {
      expect(VehicleComponentCatalog.all, hasLength(24));
      expect(
        VehicleComponentCatalog.all.first.id,
        VehicleComponentId.frontBumper,
      );
      expect(VehicleComponentCatalog.all.last.id, VehicleComponentId.roof);
    });

    test('keeps the ATD-44 labels and primary views with each identity', () {
      expect(
        VehicleComponentCatalog.all.map(
          (item) => (item.id, item.label, item.primaryView),
        ),
        [
          (VehicleComponentId.frontBumper, 'Front bumper', VehicleView.front),
          (VehicleComponentId.hood, 'Hood', VehicleView.front),
          (
            VehicleComponentId.leftHeadlight,
            'Left headlight',
            VehicleView.front,
          ),
          (
            VehicleComponentId.rightHeadlight,
            'Right headlight',
            VehicleView.front,
          ),
          (
            VehicleComponentId.leftFrontFender,
            'Left front fender',
            VehicleView.front,
          ),
          (
            VehicleComponentId.rightFrontFender,
            'Right front fender',
            VehicleView.front,
          ),
          (
            VehicleComponentId.frontWindscreen,
            'Front windscreen',
            VehicleView.front,
          ),
          (VehicleComponentId.leftMirror, 'Left mirror', VehicleView.left),
          (
            VehicleComponentId.leftFrontDoor,
            'Left front door',
            VehicleView.left,
          ),
          (VehicleComponentId.leftRearDoor, 'Left rear door', VehicleView.left),
          (
            VehicleComponentId.leftRearQuarterPanel,
            'Left rear quarter panel',
            VehicleView.left,
          ),
          (
            VehicleComponentId.leftRunningBoard,
            'Left running board',
            VehicleView.left,
          ),
          (VehicleComponentId.rightMirror, 'Right mirror', VehicleView.right),
          (
            VehicleComponentId.rightFrontDoor,
            'Right front door',
            VehicleView.right,
          ),
          (
            VehicleComponentId.rightRearDoor,
            'Right rear door',
            VehicleView.right,
          ),
          (
            VehicleComponentId.rightRearQuarterPanel,
            'Right rear quarter panel',
            VehicleView.right,
          ),
          (
            VehicleComponentId.rightRunningBoard,
            'Right running board',
            VehicleView.right,
          ),
          (VehicleComponentId.trunkLid, 'Trunk lid', VehicleView.rear),
          (VehicleComponentId.tailgate, 'Tailgate', VehicleView.rear),
          (
            VehicleComponentId.leftTaillight,
            'Left taillight',
            VehicleView.rear,
          ),
          (
            VehicleComponentId.rightTaillight,
            'Right taillight',
            VehicleView.rear,
          ),
          (VehicleComponentId.rearBumper, 'Rear bumper', VehicleView.rear),
          (
            VehicleComponentId.rearWindscreen,
            'Rear windscreen',
            VehicleView.rear,
          ),
          (VehicleComponentId.roof, 'Roof', VehicleView.top),
        ],
      );
    });

    test('decodes only exact canonical wire IDs', () {
      expect(
        VehicleComponentId.fromWire('left_front_door'),
        VehicleComponentId.leftFrontDoor,
      );
      expect(
        () => VehicleComponentId.fromWire('left-front-door'),
        throwsA(isA<VehicleComponentWireFormatException>()),
      );
      expect(
        () => VehicleComponentId.fromWire('bonnet'),
        throwsA(isA<VehicleComponentWireFormatException>()),
      );
    });

    test('resolves components by canonical identity', () {
      final component = VehicleComponentCatalog.byId(
        VehicleComponentId.rightRearQuarterPanel,
      );

      expect(component.label, 'Right rear quarter panel');
      expect(component.primaryView, VehicleView.right);
      expect(component.isSelectable, isTrue);
      expect(component.isRetired, isFalse);
    });

    test('discovers canonical components through appraiser aliases', () {
      expect(
        VehicleComponentCatalog.search('bonnet').single.id,
        VehicleComponentId.hood,
      );
      expect(VehicleComponentCatalog.search('boot').map((item) => item.id), [
        VehicleComponentId.trunkLid,
        VehicleComponentId.tailgate,
      ]);
    });

    test('lists each view in its stable catalog order', () {
      expect(
        VehicleComponentCatalog.forView(
          VehicleView.rear,
        ).map((item) => item.id),
        [
          VehicleComponentId.trunkLid,
          VehicleComponentId.tailgate,
          VehicleComponentId.leftTaillight,
          VehicleComponentId.rightTaillight,
          VehicleComponentId.rearBumper,
          VehicleComponentId.rearWindscreen,
        ],
      );
    });
  });
}
