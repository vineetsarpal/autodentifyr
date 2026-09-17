/// The five stable views used to orient an Appraiser while selecting a part.
enum VehicleView { top, front, rear, left, right }

/// A canonical, position-specific exterior Vehicle Component identity.
enum VehicleComponentId {
  frontBumper('front_bumper'),
  hood('hood'),
  leftHeadlight('left_headlight'),
  rightHeadlight('right_headlight'),
  leftFrontFender('left_front_fender'),
  rightFrontFender('right_front_fender'),
  frontWindscreen('front_windscreen'),
  leftMirror('left_mirror'),
  leftFrontDoor('left_front_door'),
  leftRearDoor('left_rear_door'),
  leftRearQuarterPanel('left_rear_quarter_panel'),
  leftRunningBoard('left_running_board'),
  rightMirror('right_mirror'),
  rightFrontDoor('right_front_door'),
  rightRearDoor('right_rear_door'),
  rightRearQuarterPanel('right_rear_quarter_panel'),
  rightRunningBoard('right_running_board'),
  trunkLid('trunk_lid'),
  tailgate('tailgate'),
  leftTaillight('left_taillight'),
  rightTaillight('right_taillight'),
  rearBumper('rear_bumper'),
  rearWindscreen('rear_windscreen'),
  roof('roof');

  const VehicleComponentId(this.wireValue);

  final String wireValue;

  /// Decodes only a current canonical wire value; aliases are never accepted.
  static VehicleComponentId fromWire(String wireValue) {
    for (final id in values) {
      if (id.wireValue == wireValue) return id;
    }
    throw VehicleComponentWireFormatException(
      'Unknown Vehicle Component ID: $wireValue.',
    );
  }
}

/// Raised when persisted data does not contain a canonical component ID.
class VehicleComponentWireFormatException implements Exception {
  const VehicleComponentWireFormatException(this.message);

  final String message;

  @override
  String toString() => 'VehicleComponentWireFormatException: $message';
}

/// Appraiser-facing metadata for a canonical [VehicleComponentId].
class VehicleComponent {
  const VehicleComponent({
    required this.id,
    required this.label,
    required this.primaryView,
    required this.order,
    this.aliases = const [],
    this.isSelectable = true,
    this.isRetired = false,
  });

  final VehicleComponentId id;
  final String label;
  final VehicleView primaryView;
  final int order;
  final List<String> aliases;
  final bool isSelectable;
  final bool isRetired;
}

/// The ordered, authoritative catalog of exterior vehicle components.
abstract final class VehicleComponentCatalog {
  static const all = <VehicleComponent>[
    VehicleComponent(
      id: VehicleComponentId.frontBumper,
      label: 'Front bumper',
      primaryView: VehicleView.front,
      order: 0,
    ),
    VehicleComponent(
      id: VehicleComponentId.hood,
      label: 'Hood',
      primaryView: VehicleView.front,
      order: 1,
      aliases: ['bonnet'],
    ),
    VehicleComponent(
      id: VehicleComponentId.leftHeadlight,
      label: 'Left headlight',
      primaryView: VehicleView.front,
      order: 2,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightHeadlight,
      label: 'Right headlight',
      primaryView: VehicleView.front,
      order: 3,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftFrontFender,
      label: 'Left front fender',
      primaryView: VehicleView.front,
      order: 4,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightFrontFender,
      label: 'Right front fender',
      primaryView: VehicleView.front,
      order: 5,
    ),
    VehicleComponent(
      id: VehicleComponentId.frontWindscreen,
      label: 'Front windscreen',
      primaryView: VehicleView.front,
      order: 6,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftMirror,
      label: 'Left mirror',
      primaryView: VehicleView.left,
      order: 7,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftFrontDoor,
      label: 'Left front door',
      primaryView: VehicleView.left,
      order: 8,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftRearDoor,
      label: 'Left rear door',
      primaryView: VehicleView.left,
      order: 9,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftRearQuarterPanel,
      label: 'Left rear quarter panel',
      primaryView: VehicleView.left,
      order: 10,
    ),
    VehicleComponent(
      id: VehicleComponentId.leftRunningBoard,
      label: 'Left running board',
      primaryView: VehicleView.left,
      order: 11,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightMirror,
      label: 'Right mirror',
      primaryView: VehicleView.right,
      order: 12,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightFrontDoor,
      label: 'Right front door',
      primaryView: VehicleView.right,
      order: 13,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightRearDoor,
      label: 'Right rear door',
      primaryView: VehicleView.right,
      order: 14,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightRearQuarterPanel,
      label: 'Right rear quarter panel',
      primaryView: VehicleView.right,
      order: 15,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightRunningBoard,
      label: 'Right running board',
      primaryView: VehicleView.right,
      order: 16,
    ),
    VehicleComponent(
      id: VehicleComponentId.trunkLid,
      label: 'Trunk lid',
      primaryView: VehicleView.rear,
      order: 17,
      aliases: ['boot'],
    ),
    VehicleComponent(
      id: VehicleComponentId.tailgate,
      label: 'Tailgate',
      primaryView: VehicleView.rear,
      order: 18,
      aliases: ['boot'],
    ),
    VehicleComponent(
      id: VehicleComponentId.leftTaillight,
      label: 'Left taillight',
      primaryView: VehicleView.rear,
      order: 19,
    ),
    VehicleComponent(
      id: VehicleComponentId.rightTaillight,
      label: 'Right taillight',
      primaryView: VehicleView.rear,
      order: 20,
    ),
    VehicleComponent(
      id: VehicleComponentId.rearBumper,
      label: 'Rear bumper',
      primaryView: VehicleView.rear,
      order: 21,
    ),
    VehicleComponent(
      id: VehicleComponentId.rearWindscreen,
      label: 'Rear windscreen',
      primaryView: VehicleView.rear,
      order: 22,
    ),
    VehicleComponent(
      id: VehicleComponentId.roof,
      label: 'Roof',
      primaryView: VehicleView.top,
      order: 23,
    ),
  ];

  static VehicleComponent byId(VehicleComponentId id) =>
      all.firstWhere((component) => component.id == id);

  /// Finds active, selectable components by label or Appraiser-facing alias.
  static List<VehicleComponent> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return all
          .where((component) => component.isSelectable && !component.isRetired)
          .toList(growable: false);
    }
    return all
        .where(
          (component) =>
              component.isSelectable &&
              !component.isRetired &&
              (component.label.toLowerCase().contains(normalizedQuery) ||
                  component.aliases.any(
                    (alias) => alias.toLowerCase().contains(normalizedQuery),
                  )),
        )
        .toList(growable: false);
  }

  /// Returns active, selectable components for [view] in catalog order.
  static List<VehicleComponent> forView(VehicleView view) => all
      .where(
        (component) =>
            component.primaryView == view &&
            component.isSelectable &&
            !component.isRetired,
      )
      .toList(growable: false);
}
