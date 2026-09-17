import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';
import 'package:autodentifyr/services/vehicle_component_geometry.dart';

/// Immutable, UI-independent state for a vehicle component picker session.
class VehicleComponentPickerState {
  const VehicleComponentPickerState({
    required this.view,
    required this.selectedId,
    required this.suggestedId,
    required this.candidateIds,
    required this.query,
    required this.ambiguity,
  });

  final VehicleView view;
  final VehicleComponentId? selectedId;
  final VehicleComponentId? suggestedId;
  final List<VehicleComponentId> candidateIds;
  final String query;
  final VehicleComponentPickerAmbiguity? ambiguity;

  /// Search is catalog-owned, so label and alias behavior stays centralized.
  List<VehicleComponent> get visibleComponents =>
      VehicleComponentCatalog.search(query);

  VehicleComponentPickerState copyWith({
    VehicleView? view,
    VehicleComponentId? selectedId,
    bool clearSelectedId = false,
    VehicleComponentId? suggestedId,
    bool clearSuggestedId = false,
    List<VehicleComponentId>? candidateIds,
    String? query,
    VehicleComponentPickerAmbiguity? ambiguity,
    bool clearAmbiguity = false,
  }) => VehicleComponentPickerState(
    view: view ?? this.view,
    selectedId: clearSelectedId ? null : selectedId ?? this.selectedId,
    suggestedId: clearSuggestedId ? null : suggestedId ?? this.suggestedId,
    candidateIds: List.unmodifiable(candidateIds ?? this.candidateIds),
    query: query ?? this.query,
    ambiguity: clearAmbiguity ? null : ambiguity ?? this.ambiguity,
  );
}

class VehicleComponentPickerAmbiguity {
  const VehicleComponentPickerAmbiguity({
    required this.candidateIds,
    required this.hasBrowseAll,
  });

  final List<VehicleComponentId> candidateIds;
  final bool hasBrowseAll;
}

sealed class VehicleComponentPickerResult {
  const VehicleComponentPickerResult();
}

final class VehicleComponentPickerCancelled
    extends VehicleComponentPickerResult {
  const VehicleComponentPickerCancelled();
}

final class VehicleComponentPickerAccepted
    extends VehicleComponentPickerResult {
  const VehicleComponentPickerAccepted(this.componentId);

  final VehicleComponentId componentId;
}

/// Owns selection-only interaction; assessment workflows apply a returned result.
class VehicleComponentPickerController extends ChangeNotifier {
  VehicleComponentPickerController({
    VehicleComponentId? existingId,
    VehicleComponentDetectorResult? detectorResult,
  }) : _openingId = existingId,
       _openingSuggestion =
           existingId == null &&
               detectorResult is ExactVehicleComponentDetectorResult
           ? detectorResult.componentId
           : null,
       _candidateIds = detectorResult is CandidateVehicleComponentDetectorResult
           ? List.unmodifiable(detectorResult.componentIds)
           : const [] {
    final openingSuggestion = _openingSuggestion;
    _openingView = existingId != null
        ? VehicleComponentCatalog.byId(existingId).primaryView
        : openingSuggestion != null
        ? VehicleComponentCatalog.byId(openingSuggestion).primaryView
        : VehicleView.top;
    _state = VehicleComponentPickerState(
      view: _openingView,
      selectedId: existingId,
      suggestedId: openingSuggestion,
      candidateIds: _candidateIds,
      query: '',
      ambiguity: null,
    );
  }

  final VehicleComponentId? _openingId;
  final VehicleComponentId? _openingSuggestion;
  final List<VehicleComponentId> _candidateIds;
  late final VehicleView _openingView;
  late VehicleComponentPickerState _state;

  VehicleComponentPickerState get state => _state;

  void changeView(VehicleView view) {
    if (_state.view == view) return;
    _emit(_state.copyWith(view: view, clearAmbiguity: true));
  }

  void updateQuery(String query) {
    if (_state.query == query) return;
    _emit(_state.copyWith(query: query));
  }

  void selectFromDiagram(VehicleComponentId componentId) =>
      _select(componentId);

  void selectFromList(VehicleComponentId componentId) => _select(componentId);

  void selectAmbiguousCandidate(VehicleComponentId componentId) {
    final ambiguity = _state.ambiguity;
    if (ambiguity == null || !ambiguity.candidateIds.contains(componentId)) {
      return;
    }
    _select(componentId);
  }

  void handleTap(VehicleComponentTapResolution resolution) {
    switch (resolution) {
      case VehicleComponentTapMiss():
        if (_state.ambiguity != null) {
          _emit(_state.copyWith(clearAmbiguity: true));
        }
        break;
      case VehicleComponentTapSingle(:final occurrence):
        _select(occurrence.componentId);
        break;
      case VehicleComponentTapAmbiguous(
        :final occurrences,
        :final hasMoreCandidates,
      ):
        _emit(
          _state.copyWith(
            ambiguity: VehicleComponentPickerAmbiguity(
              candidateIds: List.unmodifiable(
                occurrences.map((occurrence) => occurrence.componentId),
              ),
              hasBrowseAll: hasMoreCandidates,
            ),
          ),
        );
        break;
    }
  }

  void undo() {
    final next = _state.copyWith(
      view: _openingView,
      selectedId: _openingId,
      clearSelectedId: _openingId == null,
      suggestedId: _openingSuggestion,
      clearSuggestedId: _openingSuggestion == null,
      clearAmbiguity: true,
    );
    if (next.selectedId == _state.selectedId &&
        next.suggestedId == _state.suggestedId &&
        next.view == _state.view &&
        next.ambiguity == _state.ambiguity) {
      return;
    }
    _emit(next);
  }

  VehicleComponentPickerCancelled cancel() =>
      const VehicleComponentPickerCancelled();

  VehicleComponentPickerAccepted? useSelection() {
    final selectedId = _state.selectedId;
    return selectedId == null
        ? null
        : VehicleComponentPickerAccepted(selectedId);
  }

  void _select(VehicleComponentId componentId) {
    final view = VehicleComponentCatalog.byId(componentId).primaryView;
    if (_state.selectedId == componentId &&
        _state.suggestedId == null &&
        _state.view == view &&
        _state.ambiguity == null) {
      return;
    }
    _emit(
      _state.copyWith(
        view: view,
        selectedId: componentId,
        clearSuggestedId: true,
        clearAmbiguity: true,
      ),
    );
  }

  void _emit(VehicleComponentPickerState state) {
    _state = state;
    notifyListeners();
  }
}
