import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/vehicle_component_picker_controller.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/presentation/widgets/observation_evidence.dart';
import 'package:autodentifyr/presentation/widgets/vehicle_component_diagram.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';

/// Full-screen, local-only selection flow. It returns an identity but never
/// writes an assessment; the parent form owns the correction on submission.
class VehicleComponentPickerEvidence {
  VehicleComponentPickerEvidence({
    required List<Capture> captures,
    required List<DamageObservation> observations,
    required this.initiatingObservationId,
  }) : captures = List.unmodifiable(captures),
       observations = List.unmodifiable(observations);

  final List<Capture> captures;
  final List<DamageObservation> observations;
  final String initiatingObservationId;

  List<_ObservationEvidenceItem> get _orderedObservations {
    final capturesById = {for (final capture in captures) capture.id: capture};
    final items = observations
        .map(
          (observation) => switch (capturesById[observation.captureId]) {
            final Capture capture => _ObservationEvidenceItem(
              capture: capture,
              observation: observation,
            ),
            null => null,
          },
        )
        .whereType<_ObservationEvidenceItem>()
        .toList(growable: false);
    final initiatingIndex = items.indexWhere(
      (item) => item.observation.id == initiatingObservationId,
    );
    if (initiatingIndex < 0) return items;
    return [
      items[initiatingIndex],
      for (var index = 0; index < items.length; index++)
        if (index != initiatingIndex) items[index],
    ];
  }
}

class VehicleComponentPickerScreen extends StatefulWidget {
  const VehicleComponentPickerScreen({
    super.key,
    this.existingId,
    this.detectorResult,
    this.geometry,
    this.evidence,
    this.existingFindings = const [],
  });

  final VehicleComponentId? existingId;
  final VehicleComponentDetectorResult? detectorResult;
  final VehicleComponentGeometry? geometry;
  final VehicleComponentPickerEvidence? evidence;
  final List<VehicleComponentExistingFinding> existingFindings;

  @override
  State<VehicleComponentPickerScreen> createState() =>
      _VehicleComponentPickerScreenState();
}

class _VehicleComponentPickerScreenState
    extends State<VehicleComponentPickerScreen> {
  static const _transitionDuration = Duration(milliseconds: 200);
  static const _wideLayoutMinWidth = 720.0;

  late final VehicleComponentPickerController _controller;
  final _browseButtonFocusNode = FocusNode();
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
    _browseButtonFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop();

  bool get _usesAndroidHaptics =>
      defaultTargetPlatform == TargetPlatform.android;

  void _useSelection() {
    final result = _controller.useSelection();
    if (result case VehicleComponentPickerAccepted(:final componentId)) {
      if (_usesAndroidHaptics) HapticFeedback.mediumImpact();
      Navigator.of(context).pop(componentId);
    }
  }

  void _previewSelection(VehicleComponentId componentId) {
    setState(() => _diagramGuidance = null);
    _controller.selectFromDiagram(componentId);
    if (_usesAndroidHaptics) HapticFeedback.selectionClick();
  }

  void _selectFromDiagram(VehicleComponentId componentId) =>
      _previewSelection(componentId);

  void _changeView(VehicleView view) => _controller.changeView(view);

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
        if (_usesAndroidHaptics) HapticFeedback.selectionClick();
      case VehicleComponentTapAmbiguous(:final occurrences):
        setState(() => _diagramGuidance = null);
        _showAmbiguity(occurrences);
    }
  }

  Future<void> _showExistingFinding(
    VehicleComponentExistingFinding finding,
  ) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Existing finding',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Part: ${VehicleComponentCatalog.byId(finding.componentId).label}',
            ),
            Text('Status: ${finding.statusLabel}'),
            if (finding.damageType case final damageType?)
              Text('Damage: $damageType'),
            const SizedBox(height: 12),
            const Text(
              'This is read-only context. Your current component selection has not changed.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _handleHorizontalDrag(DragEndDetails details, VehicleView view) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;
    const lateralViews = [
      VehicleView.left,
      VehicleView.front,
      VehicleView.right,
      VehicleView.rear,
    ];
    final index = lateralViews.indexOf(view);
    if (index < 0) return;
    final delta = velocity < 0 ? 1 : -1;
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= lateralViews.length) return;
    _changeView(lateralViews[nextIndex]);
  }

  Future<void> _showAmbiguity(
    List<VehicleComponentOccurrence> occurrences,
  ) async {
    var browseAll = false;
    await showModalBottomSheet<void>(
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
                    leading: _spatialPreview(occurrence.componentId),
                    title: Text(
                      VehicleComponentCatalog.byId(
                        occurrence.componentId,
                      ).label,
                    ),
                    subtitle: Text(_spatialHint(occurrence.componentId)),
                    onTap: () {
                      _controller.selectAmbiguousCandidate(
                        occurrence.componentId,
                      );
                      if (_usesAndroidHaptics) HapticFeedback.selectionClick();
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                TextButton.icon(
                  key: const Key('ambiguity-browse-all-components'),
                  onPressed: () {
                    browseAll = true;
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.format_list_bulleted),
                  label: const Text('Browse all components'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || !browseAll || _controller.state.selectedId != null) return;
    await _showBrowseSheet();
  }

  Future<void> _showBrowseSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
        maxWidth: 680,
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: _ComponentBrowseSheet(
          controller: _controller,
          onSelected: (componentId) {
            _previewSelection(componentId);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
    if (mounted) _browseButtonFocusNode.requestFocus();
  }

  Widget _spatialPreview(VehicleComponentId componentId) => SizedBox(
    width: 40,
    height: 40,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _viewIcon(VehicleComponentCatalog.byId(componentId).primaryView),
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
      final vehicle = _vehicleStage(state);
      final details = _details(state);
      final body = constraints.maxWidth >= _wideLayoutMinWidth
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: vehicle),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [vehicle, const SizedBox(height: 16), details],
            );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: body,
          ),
        ),
      );
    },
  );

  Widget _vehicleStage(VehicleComponentPickerState state) {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select the affected area',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a vehicle panel, or choose a view to orient the diagram.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _viewChooser(state),
        const SizedBox(height: 12),
        GestureDetector(
          key: const Key('vehicle-view-swipe-area'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) =>
              _handleHorizontalDrag(details, state.view),
          child: AnimatedSwitcher(
            duration: reducedMotion ? Duration.zero : _transitionDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.035, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(state.view),
              child: VehicleComponentDiagram(
                view: state.view,
                selectedId: state.selectedId,
                suggestedId: state.suggestedId,
                candidateIds: state.selectedId == null
                    ? state.candidateIds
                    : const [],
                existingFindings: widget.existingFindings,
                onSelected: _selectFromDiagram,
                onExistingFindingSelected: _showExistingFinding,
                onTapResolution: _handleDiagramTap,
                geometry: widget.geometry,
              ),
            ),
          ),
        ),
        if (_diagramGuidance case final guidance?) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: Text(guidance)),
        ],
      ],
    );
  }

  Widget _details(VehicleComponentPickerState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _selectionSummary(state),
      if (_pickerEvidenceItems.isNotEmpty) ...[
        const SizedBox(height: 12),
        _evidenceStrip(_pickerEvidenceItems),
      ],
      if (state.selectedId == null &&
          (state.suggestedId != null || state.candidateIds.isNotEmpty)) ...[
        const SizedBox(height: 12),
        _detectorQuestion(state),
      ],
      if (state.suggestedId case final suggestedId?) ...[
        const SizedBox(height: 12),
        _suggestedChoice(suggestedId),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('browse-components'),
        focusNode: _browseButtonFocusNode,
        onPressed: _showBrowseSheet,
        icon: const Icon(Icons.search),
        label: const Text('Browse or search components'),
      ),
    ],
  );

  List<_ObservationEvidenceItem> get _pickerEvidenceItems =>
      widget.evidence?._orderedObservations ?? const [];

  Widget _evidenceStrip(List<_ObservationEvidenceItem> evidence) => Semantics(
    container: true,
    label: 'Supporting model evidence',
    child: Card(
      key: const Key('picker-evidence-strip'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evidence.length == 1
                  ? 'Supporting evidence'
                  : 'Supporting evidence (${evidence.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 152,
              child: PageView.builder(
                key: const Key('picker-evidence-carousel'),
                itemCount: evidence.length,
                itemBuilder: (context, index) => _evidenceCard(evidence[index]),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _evidenceCard(_ObservationEvidenceItem item) {
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      button: true,
      label:
          'Open ${item.observation.rawClass}, ${(item.observation.confidence * 100).toStringAsFixed(1)} percent confidence evidence',
      child: InkWell(
        key: Key('open-picker-evidence-${item.observation.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ObservationEvidenceViewer(
              capture: item.capture,
              observation: item.observation,
              closeKey: const Key('close-picker-evidence'),
              imageKey: Key('picker-evidence-image-${item.observation.id}'),
              boundsKey: Key('picker-evidence-bounds-${item.observation.id}'),
            ),
          ),
        ),
        child: usesLargeText
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.observation.rawClass,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(item.observation.confidence * 100).toStringAsFixed(1)}% confidence',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to inspect evidence',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 104,
                      child: ObservationImageOverlay(
                        capture: item.capture,
                        observation: item.observation,
                        imageKey: Key(
                          'picker-evidence-thumbnail-${item.observation.id}',
                        ),
                        boundsKey: Key(
                          'picker-evidence-thumbnail-bounds-${item.observation.id}',
                        ),
                        outlineColor: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.observation.rawClass,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(item.observation.confidence * 100).toStringAsFixed(1)}% confidence',
                        ),
                        const SizedBox(height: 4),
                        const Text('Tap to inspect bounds'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _selectionSummary(VehicleComponentPickerState state) {
    final id = state.selectedId;
    final label = id == null
        ? 'No component selected'
        : VehicleComponentCatalog.byId(id).label;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _transitionDuration,
        decoration: BoxDecoration(
          color: id == null
              ? null
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                id == null ? Icons.touch_app_outlined : Icons.check_circle,
                color: id == null
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Component',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Part: $label',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            onSelected: (_) => _changeView(view),
          ),
      ],
    ),
  );

  Widget _suggestedChoice(VehicleComponentId id) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Suggested: ${VehicleComponentCatalog.byId(id).label}'),
          ),
          TextButton(
            key: const Key('use-suggested-component'),
            onPressed: () => _previewSelection(id),
            child: const Text('Use'),
          ),
        ],
      ),
    ),
  );

  Widget _detectorQuestion(VehicleComponentPickerState state) => Semantics(
    key: const Key('picker-contextual-prompt'),
    liveRegion: true,
    container: true,
    label: state.suggestedId != null
        ? 'Review the highlighted suggestion, then choose Use if it matches.'
        : 'Which highlighted component is affected?',
    child: Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              state.suggestedId != null
                  ? Icons.auto_awesome_outlined
                  : Icons.help_outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.suggestedId != null
                    ? 'Review the highlighted suggestion, then choose Use if it matches.'
                    : 'Which highlighted component is affected?',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ObservationEvidenceItem {
  const _ObservationEvidenceItem({
    required this.capture,
    required this.observation,
  });

  final Capture capture;
  final DamageObservation observation;
}

class _ComponentBrowseSheet extends StatefulWidget {
  const _ComponentBrowseSheet({
    required this.controller,
    required this.onSelected,
  });

  final VehicleComponentPickerController controller;
  final ValueChanged<VehicleComponentId> onSelected;

  @override
  State<_ComponentBrowseSheet> createState() => _ComponentBrowseSheetState();
}

class _ComponentBrowseSheetState extends State<_ComponentBrowseSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.state.query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final candidates = state.selectedId == null
            ? state.candidateIds
            : const <VehicleComponentId>[];
        final candidateSet = candidates.toSet();
        final activeViewChoices = VehicleComponentCatalog.forView(
          state.view,
        ).where((component) => !candidateSet.contains(component.id));
        final searchResults = state.visibleComponents;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Browse vehicle components',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('component-search'),
                controller: _searchController,
                autofocus: true,
                onChanged: widget.controller.updateQuery,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search all components',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  key: const Key('component-browse-list'),
                  shrinkWrap: true,
                  children: [
                    if (candidates.isNotEmpty) ...[
                      _sectionTitle(context, 'Suggested components'),
                      for (final id in candidates)
                        _choice(
                          context,
                          VehicleComponentCatalog.byId(id),
                          keyPrefix: 'candidate-component',
                          leading: const Icon(Icons.auto_awesome_outlined),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (state.query.trim().isEmpty) ...[
                      _sectionTitle(
                        context,
                        'Active view choices: ${_viewLabel(state.view)}',
                      ),
                      if (activeViewChoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No additional choices in this view.'),
                        ),
                      for (final component in activeViewChoices)
                        _choice(
                          context,
                          component,
                          keyPrefix: 'picker-active-component',
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (state.query.trim().isNotEmpty) ...[
                      _sectionTitle(context, 'Search results'),
                      if (searchResults.isEmpty)
                        const Padding(
                          key: Key('component-search-empty-results'),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No components match that search.'),
                        ),
                      for (final component in searchResults)
                        _choice(context, component),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _sectionTitle(BuildContext context, String label) => Semantics(
    header: true,
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _choice(
    BuildContext context,
    VehicleComponent component, {
    String keyPrefix = 'picker-component',
    Widget? leading,
  }) => Semantics(
    key: Key('$keyPrefix-${component.id.wireValue}'),
    button: true,
    label: component.label,
    onTap: () => widget.onSelected(component.id),
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: 48,
      ),
      child: TextButton.icon(
        key: Key('$keyPrefix-button-${component.id.wireValue}'),
        onPressed: () => widget.onSelected(component.id),
        icon: leading ?? Icon(_viewIcon(component.primaryView)),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(component.label),
          ),
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

String _spatialHint(VehicleComponentId componentId) => switch (componentId) {
  VehicleComponentId.frontBumper => 'Front centre, lower edge',
  VehicleComponentId.hood => 'Front centre, upper panel',
  VehicleComponentId.leftHeadlight => 'Vehicle left, front outer light',
  VehicleComponentId.rightHeadlight => 'Vehicle right, front outer light',
  VehicleComponentId.leftFrontFender => 'Vehicle left, front outer wheel arch',
  VehicleComponentId.rightFrontFender =>
    'Vehicle right, front outer wheel arch',
  VehicleComponentId.frontWindscreen => 'Front centre, upper glass',
  VehicleComponentId.leftMirror => 'Vehicle left, front side mirror',
  VehicleComponentId.leftFrontDoor => 'Vehicle left, front side door',
  VehicleComponentId.leftRearDoor => 'Vehicle left, rear side door',
  VehicleComponentId.leftRearQuarterPanel => 'Vehicle left, rear outer panel',
  VehicleComponentId.leftRunningBoard => 'Vehicle left, lower side step',
  VehicleComponentId.rightMirror => 'Vehicle right, front side mirror',
  VehicleComponentId.rightFrontDoor => 'Vehicle right, front side door',
  VehicleComponentId.rightRearDoor => 'Vehicle right, rear side door',
  VehicleComponentId.rightRearQuarterPanel => 'Vehicle right, rear outer panel',
  VehicleComponentId.rightRunningBoard => 'Vehicle right, lower side step',
  VehicleComponentId.trunkLid => 'Rear centre, upper lid',
  VehicleComponentId.tailgate => 'Rear centre, upper tailgate',
  VehicleComponentId.leftTaillight => 'Vehicle left, rear outer light',
  VehicleComponentId.rightTaillight => 'Vehicle right, rear outer light',
  VehicleComponentId.rearBumper => 'Rear centre, lower edge',
  VehicleComponentId.rearWindscreen => 'Rear centre, upper glass',
  VehicleComponentId.roof => 'Top centre, roof panel',
};

IconData _viewIcon(VehicleView view) => switch (view) {
  VehicleView.front => Icons.arrow_upward,
  VehicleView.rear => Icons.arrow_downward,
  VehicleView.left => Icons.arrow_back,
  VehicleView.right => Icons.arrow_forward,
  VehicleView.top => Icons.vertical_align_top,
};
