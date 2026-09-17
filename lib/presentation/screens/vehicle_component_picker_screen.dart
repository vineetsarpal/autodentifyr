import 'package:flutter/material.dart';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/vehicle_component_picker_controller.dart';
import 'package:autodentifyr/presentation/widgets/vehicle_component_diagram.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';

/// Full-screen, local-only selection flow. It returns an identity but never
/// writes an assessment; the parent form owns the correction on submission.
class VehicleComponentPickerScreen extends StatefulWidget {
  const VehicleComponentPickerScreen({
    super.key,
    this.existingId,
    this.detectorResult,
    this.geometry,
  });

  final VehicleComponentId? existingId;
  final VehicleComponentDetectorResult? detectorResult;
  final VehicleComponentGeometry? geometry;

  @override
  State<VehicleComponentPickerScreen> createState() =>
      _VehicleComponentPickerScreenState();
}

class _VehicleComponentPickerScreenState
    extends State<VehicleComponentPickerScreen> {
  late final VehicleComponentPickerController _controller;
  final _searchController = TextEditingController();
  String? _diagramGuidance;

  @override
  void initState() {
    super.initState();
    _controller = VehicleComponentPickerController(
      existingId: widget.existingId,
      detectorResult: widget.detectorResult,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  void _useSelection() {
    final result = _controller.useSelection();
    if (result case VehicleComponentPickerAccepted(:final componentId)) {
      Navigator.of(context).pop(componentId);
    }
  }

  void _selectFromDiagram(VehicleComponentId componentId) {
    setState(() => _diagramGuidance = null);
    _controller.selectFromDiagram(componentId);
  }

  void _handleDiagramTap(VehicleComponentTapResolution resolution) {
    _controller.handleTap(resolution);
    switch (resolution) {
      case VehicleComponentTapMiss():
        setState(
          () => _diagramGuidance =
              'Tap a highlighted vehicle component or choose one from the list.',
        );
      case VehicleComponentTapSingle():
        setState(() => _diagramGuidance = null);
      case VehicleComponentTapAmbiguous(:final occurrences):
        setState(() => _diagramGuidance = null);
        _showAmbiguity(occurrences);
    }
  }

  Future<void> _showAmbiguity(
    List<VehicleComponentOccurrence> occurrences,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .75,
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose the affected component',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('That tap overlaps more than one component.'),
              const SizedBox(height: 8),
              for (final occurrence in occurrences)
                ListTile(
                  key: Key(
                    'ambiguity-component-${occurrence.componentId.wireValue}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    VehicleComponentCatalog.byId(occurrence.componentId).label,
                  ),
                  onTap: () {
                    _controller.selectAmbiguousCandidate(
                      occurrence.componentId,
                    );
                    Navigator.of(sheetContext).pop();
                  },
                ),
              TextButton.icon(
                key: const Key('ambiguity-browse-all-components'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Browse all components'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (_, _) => _controller.cancel(),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Choose vehicle component'),
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton.icon(
            key: const Key('picker-undo'),
            onPressed: _controller.undo,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(_controller.state),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            key: const Key('use-component-selection'),
            onPressed: _controller.state.selectedId == null
                ? null
                : _useSelection,
            child: Text(
              _controller.state.selectedId == null
                  ? 'Select a component'
                  : 'Use ${VehicleComponentCatalog.byId(_controller.state.selectedId!).label}',
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBody(VehicleComponentPickerState state) => LayoutBuilder(
    builder: (context, constraints) {
      final content = <Widget>[
        _selectionSummary(state),
        const SizedBox(height: 12),
        _viewChooser(state),
        const SizedBox(height: 12),
      ];
      final diagram = VehicleComponentDiagram(
        view: state.view,
        selectedId: state.selectedId,
        suggestedId: state.suggestedId,
        onSelected: _selectFromDiagram,
        onTapResolution: _handleDiagramTap,
        geometry: widget.geometry,
      );
      final browse = _browseComponents(state);
      if (constraints.maxWidth >= 720) {
        content.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: diagram),
              const SizedBox(width: 16),
              Expanded(child: browse),
            ],
          ),
        );
      } else {
        content.addAll([diagram, const SizedBox(height: 16), browse]);
      }
      if (_diagramGuidance case final guidance?) {
        content.addAll([
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(guidance)),
        ]);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
      );
    },
  );

  Widget _selectionSummary(VehicleComponentPickerState state) {
    final id = state.selectedId;
    final label = id == null
        ? 'No component selected'
        : VehicleComponentCatalog.byId(id).label;
    return Semantics(
      liveRegion: true,
      child: Text(
        'Part: $label',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _viewChooser(VehicleComponentPickerState state) => Semantics(
    label: 'Vehicle view',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final view in VehicleView.values)
          ChoiceChip(
            key: Key('picker-view-${view.name}'),
            label: Text(_viewLabel(view)),
            selected: state.view == view,
            onSelected: (_) => _controller.changeView(view),
          ),
      ],
    ),
  );

  Widget _browseComponents(VehicleComponentPickerState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (state.selectedId == null && state.candidateIds.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose one of these suggested components',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final id in state.candidateIds)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      key: Key('candidate-component-${id.wireValue}'),
                      onPressed: () => _controller.selectFromList(id),
                      icon: const Icon(Icons.location_on_outlined),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(VehicleComponentCatalog.byId(id).label),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (state.selectedId == null && state.candidateIds.isNotEmpty)
        const SizedBox(height: 12),
      if (state.suggestedId case final suggestedId?)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested: ${VehicleComponentCatalog.byId(suggestedId).label}',
                  ),
                ),
                TextButton(
                  key: const Key('use-suggested-component'),
                  onPressed: () => _controller.selectFromList(suggestedId),
                  child: const Text('Use'),
                ),
              ],
            ),
          ),
        ),
      if (state.suggestedId != null) const SizedBox(height: 12),
      TextField(
        key: const Key('component-search'),
        controller: _searchController,
        onChanged: _controller.updateQuery,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Search all components',
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Active view choices',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      for (final component in VehicleComponentCatalog.forView(state.view))
        _componentChoice(
          component,
          state.selectedId,
          keyPrefix: 'picker-active-component',
        ),
      const SizedBox(height: 12),
      Text('All components', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      for (final view in VehicleView.values) ...[
        if (state.visibleComponents.any((item) => item.primaryView == view))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _viewLabel(view),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        for (final component in state.visibleComponents.where(
          (item) => item.primaryView == view,
        ))
          _componentChoice(component, state.selectedId),
      ],
    ],
  );

  Widget _componentChoice(
    VehicleComponent component,
    VehicleComponentId? selectedId, {
    String keyPrefix = 'picker-component',
  }) => Semantics(
    key: Key('$keyPrefix-${component.id.wireValue}'),
    button: true,
    selected: selectedId == component.id,
    label: component.label,
    onTap: () => _controller.selectFromList(component.id),
    child: SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton.icon(
        onPressed: () => _controller.selectFromList(component.id),
        icon: Icon(
          selectedId == component.id
              ? Icons.check_circle
              : Icons.circle_outlined,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(component.label),
        ),
      ),
    ),
  );
}

String _viewLabel(VehicleView view) => switch (view) {
  VehicleView.front => 'Front',
  VehicleView.left => 'Left',
  VehicleView.right => 'Right',
  VehicleView.rear => 'Rear',
  VehicleView.top => 'Top',
};
