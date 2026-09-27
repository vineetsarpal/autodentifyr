import 'package:flutter/material.dart';

import '../../models/vehicle_component.dart';
import '../models/vehicle_finding_map_item.dart';
import '../widgets/vehicle_findings_map_geometry.dart';

/// Full-screen, transaction-local component selection on one unfolded top map.
class VehicleComponentMapScreen extends StatefulWidget {
  const VehicleComponentMapScreen({
    super.key,
    required this.items,
    this.initialComponent,
    this.dismissedFindingCounts = const {},
    this.suggestedComponents = const [],
    this.suggestionConfidence,
    this.onViewEvidence,
  });

  final List<VehicleFindingMapItem> items;
  final VehicleComponentId? initialComponent;
  final Map<VehicleComponentId, int> dismissedFindingCounts;
  final List<VehicleComponentId> suggestedComponents;
  final double? suggestionConfidence;
  final ValueChanged<String>? onViewEvidence;

  @override
  State<VehicleComponentMapScreen> createState() =>
      _VehicleComponentMapScreenState();
}

class _VehicleComponentMapScreenState extends State<VehicleComponentMapScreen> {
  final TransformationController _transformationController =
      TransformationController();
  VehicleComponentId? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialComponent;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Map<VehicleComponentId, int> get _findingCounts {
    final counts = <VehicleComponentId, int>{};
    for (final item in widget.items) {
      counts.update(item.componentId, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  void _select(VehicleComponentId componentId) =>
      setState(() => _selected = componentId);

  void _resetView() => _transformationController.value = Matrix4.identity();

  Future<void> _handleMapTap(Size size, Offset position) async {
    final candidates = hitTestVehicleMapCandidates(
      VehicleView.top,
      size,
      position,
    );
    if (candidates.isEmpty) return;
    if (candidates.length == 1) {
      _select(candidates.single);
      return;
    }
    final selected = await showModalBottomSheet<VehicleComponentId>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Which component?')),
            for (final candidate in candidates)
              ListTile(
                title: Text(VehicleComponentCatalog.byId(candidate).label),
                onTap: () => Navigator.pop(sheetContext, candidate),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) _select(selected);
  }

  Future<void> _browseComponents() async {
    var query = '';
    final selected = await showModalBottomSheet<VehicleComponentId>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final matches = VehicleComponentCatalog.search(query);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                children: [
                  Text(
                    'Browse components',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('top-map-component-search'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search all components',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final component = matches[index];
                        final count = _findingCounts[component.id] ?? 0;
                        return ListTile(
                          key: Key(
                            'top-map-component-${component.id.wireValue}',
                          ),
                          title: Text(component.label),
                          subtitle: count == 0
                              ? null
                              : Text('$count existing findings'),
                          trailing: component.id == _selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () =>
                              Navigator.pop(sheetContext, component.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected != null && mounted) _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compactChrome =
        mediaQuery.size.width < 420 || mediaQuery.textScaler.scale(1) > 1.3;
    final selectedItems = widget.items
        .where((item) => item.componentId == _selected)
        .toList(growable: false);
    final dismissedCount = _selected == null
        ? 0
        : widget.dismissedFindingCounts[_selected] ?? 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('cancel-component-map'),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(compactChrome ? 'Component' : 'Select vehicle component'),
        actions: [
          if (compactChrome)
            IconButton(
              tooltip: 'Browse components',
              onPressed: _browseComponents,
              icon: const Icon(Icons.search),
            )
          else
            TextButton.icon(
              onPressed: _browseComponents,
              icon: const Icon(Icons.search),
              label: const Text('Browse components'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final map = _MapSurface(
              transformationController: _transformationController,
              selectedComponent: _selected,
              findingCounts: _findingCounts,
              onSelected: _select,
              onTap: _handleMapTap,
              onReset: _resetView,
            );
            final panel = _SelectionPanel(
              selectedComponent: _selected,
              items: selectedItems,
              dismissedCount: dismissedCount,
              suggestedComponents: widget.suggestedComponents,
              suggestionConfidence: widget.suggestionConfidence,
              onSelectComponent: _select,
              onViewEvidence: widget.onViewEvidence,
              onUse: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: map),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 340, child: panel),
                ],
              );
            }
            final largeText = mediaQuery.textScaler.scale(1) > 1.3;
            final initialSheetSize = largeText ? .58 : .30;
            final mapBottomClearance =
                constraints.maxHeight * initialSheetSize - 12;
            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: mapBottomClearance),
                    child: map,
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: initialSheetSize,
                  minChildSize: largeText ? .45 : .24,
                  maxChildSize: largeText ? .82 : .72,
                  snap: true,
                  builder: (context, scrollController) => Material(
                    key: const Key('component-selection-sheet'),
                    elevation: 12,
                    color: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _SelectionPanel(
                      selectedComponent: _selected,
                      items: selectedItems,
                      dismissedCount: dismissedCount,
                      suggestedComponents: widget.suggestedComponents,
                      suggestionConfidence: widget.suggestionConfidence,
                      onSelectComponent: _select,
                      onViewEvidence: widget.onViewEvidence,
                      onUse: _selected == null
                          ? null
                          : () => Navigator.pop(context, _selected),
                      scrollController: scrollController,
                      showDragHandle: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapSurface extends StatelessWidget {
  const _MapSurface({
    required this.transformationController,
    required this.selectedComponent,
    required this.findingCounts,
    required this.onSelected,
    required this.onTap,
    required this.onReset,
  });

  final TransformationController transformationController;
  final VehicleComponentId? selectedComponent;
  final Map<VehicleComponentId, int> findingCounts;
  final ValueChanged<VehicleComponentId> onSelected;
  final Future<void> Function(Size, Offset) onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactChrome =
        MediaQuery.sizeOf(context).width < 420 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pinch to zoom. Tap a component to preview it.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (compactChrome)
                IconButton(
                  tooltip: 'Reset view',
                  onPressed: onReset,
                  icon: const Icon(Icons.center_focus_strong),
                )
              else
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Reset view'),
                ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    key: const Key('vehicle-map-frame'),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      transformationController: transformationController,
                      minScale: 1,
                      maxScale: 3,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  onTap(size, details.localPosition),
                              child: CustomPaint(
                                size: size,
                                painter: VehicleFindingsMapGeometry(
                                  view: VehicleView.top,
                                  selectedComponent: selectedComponent,
                                  findingCounts: findingCounts,
                                  onComponentSelected: onSelected,
                                  ink: theme.colorScheme.onSurface,
                                  detail: theme.dividerColor,
                                  paper: theme.colorScheme.surface,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(child: _OrientationLabel('FRONT')),
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(child: _OrientationLabel('REAR')),
                  ),
                ),
                const Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(child: _OrientationLabel('LEFT')),
                  ),
                ),
                const Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(child: _OrientationLabel('RIGHT')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrientationLabel extends StatelessWidget {
  const _OrientationLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.selectedComponent,
    required this.items,
    required this.dismissedCount,
    required this.suggestedComponents,
    required this.suggestionConfidence,
    required this.onSelectComponent,
    required this.onViewEvidence,
    required this.onUse,
    this.scrollController,
    this.showDragHandle = false,
  });

  final VehicleComponentId? selectedComponent;
  final List<VehicleFindingMapItem> items;
  final int dismissedCount;
  final List<VehicleComponentId> suggestedComponents;
  final double? suggestionConfidence;
  final ValueChanged<VehicleComponentId> onSelectComponent;
  final ValueChanged<String>? onViewEvidence;
  final VoidCallback? onUse;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final component = selectedComponent == null
        ? null
        : VehicleComponentCatalog.byId(selectedComponent!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ListView(
        controller: scrollController,
        children: [
          if (showDragHandle)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Text(
            component?.label ?? 'No component selected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            component == null
                ? 'Select a component on the vehicle or browse the list.'
                : items.isEmpty
                ? 'No active findings on this component.'
                : '${items.length} active ${items.length == 1 ? 'finding' : 'findings'} on this component.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onUse,
            child: Text(
              selectedComponent == null
                  ? 'Select a component'
                  : items.isEmpty
                  ? 'Use ${component!.label}'
                  : 'Use component anyway',
            ),
          ),
          const SizedBox(height: 8),
          if (suggestedComponents case [final suggestion]) ...[
            Text(
              'Suggested: ${VehicleComponentCatalog.byId(suggestion).label}',
            ),
            if (suggestionConfidence != null)
              Text(
                '${(suggestionConfidence! * 100).toStringAsFixed(1)}% confidence',
              ),
            TextButton(
              key: Key('candidate-component-${suggestion.wireValue}'),
              onPressed: () => onSelectComponent(suggestion),
              child: const Text('Preview suggestion'),
            ),
            const SizedBox(height: 8),
          ] else if (suggestedComponents.isNotEmpty) ...[
            Text(
              'Suggested components',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (suggestionConfidence != null)
              Text(
                '${(suggestionConfidence! * 100).toStringAsFixed(1)}% confidence',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestedComponents)
                  OutlinedButton(
                    key: Key('candidate-component-${suggestion.wireValue}'),
                    onPressed: () => onSelectComponent(suggestion),
                    child: Text(VehicleComponentCatalog.byId(suggestion).label),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          for (final item in items)
            Card(
              child: ListTile(
                leading: Icon(_stateIcon(item.state)),
                title: Text(item.damageType),
                subtitle: Text(
                  [
                    _stateLabel(item.state),
                    if (item.confidence != null)
                      '${(item.confidence! * 100).round()}% confidence',
                    '${item.evidenceCount} evidence ${item.evidenceCount == 1 ? 'item' : 'items'}',
                  ].join(' • '),
                ),
                trailing: onViewEvidence == null
                    ? null
                    : IconButton(
                        tooltip: 'View evidence',
                        onPressed: () => onViewEvidence!(item.findingId),
                        icon: const Icon(Icons.photo_library_outlined),
                      ),
              ),
            ),
          if (dismissedCount > 0)
            ExpansionTile(
              title: Text(
                '$dismissedCount dismissed ${dismissedCount == 1 ? 'finding' : 'findings'}',
              ),
              children: const [
                ListTile(
                  title: Text(
                    'Dismissed findings remain in the assessment audit history.',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _stateLabel(VehicleFindingMapState state) => switch (state) {
  VehicleFindingMapState.proposed => 'Proposed',
  VehicleFindingMapState.uncertain => 'Uncertain',
  VehicleFindingMapState.confirmed => 'Confirmed',
  VehicleFindingMapState.undetermined => 'Undetermined',
  VehicleFindingMapState.manual => 'Manual',
};

IconData _stateIcon(VehicleFindingMapState state) => switch (state) {
  VehicleFindingMapState.proposed => Icons.pending_outlined,
  VehicleFindingMapState.uncertain => Icons.warning_amber_rounded,
  VehicleFindingMapState.confirmed => Icons.check_circle_outline,
  VehicleFindingMapState.undetermined => Icons.help_outline,
  VehicleFindingMapState.manual => Icons.edit_outlined,
};
