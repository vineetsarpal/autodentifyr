# Vehicle Component Picker — physical Pixel accessibility checklist

This checklist is the release evidence record for the production vehicle-component picker. Automated tests provide the repeatable gate; the checks below require a physical Android device and human verification.

## Evidence record

- Build/commit: ______________________________
- Device/model: ______________________________
- Android version / API: ______________________
- Tester: ____________________________________
- Date (local): ______________________________
- App version: ________________________________
- Automated commands and results:
  - `flutter test test/presentation/widgets/vehicle_component_picker_accessibility_test.dart`: __________
  - `flutter test integration_test/vehicle_component_picker_test.dart`: __________
  - `flutter analyze`: __________

Record the minimum supported Android API and the API used for this run: minimum ______ / current ______.

## Automated gate

- [ ] `androidTapTargetGuideline` passes for picker controls and component targets.
- [ ] `labeledTapTargetGuideline` passes for every actionable control.
- [ ] `textContrastGuideline` passes for labels, selected state, suggestion state, errors, and disabled controls.
- [ ] Semantics tests verify names, actions, selected state, suggested state, and traversal order.
- [ ] Keyboard focus/traversal smoke test passes.
- [ ] At 320 logical px and 200% text scaling, the picker has no overflow or clipped controls.
- [ ] Integration flow covers diagram and list routes and remains deterministic without Firebase, camera, credentials, or network access.
- [ ] Cancel, Undo, Use, and system Back preserve or discard local picker state as specified.
- [ ] Rebuild/rotation preservation test passes where the harness supports it.

## Physical device setup

- [ ] Install the exact release candidate build on a physical Pixel.
- [ ] Note device model, Android version, API level, display size, font size, and display density.
- [ ] Capture screenshots or screen recordings for any failure, including the device settings used.
- [ ] Run Android Accessibility Scanner and attach its report or screenshots.

## Screen reader and switch access

- [ ] TalkBack enabled: swipe navigation reaches the title, view controls, search/list controls, diagram targets, Undo, Cancel, and Use in logical order.
- [ ] TalkBack announces each component name and view, selected state, and Suggested state where applicable.
- [ ] TalkBack announces actionable semantics and does not expose decorative diagram paths twice.
- [ ] TalkBack touch exploration can reach each sufficiently large component target.
- [ ] TalkBack back gesture/system Back returns to the parent without accidentally accepting a selection.
- [ ] Switch Access scans in a useful order and activates every required action.
- [ ] Switch Access exposes ambiguous candidates and the final Use action.

## Keyboard, text, and display conditions

- [ ] Hardware keyboard or Android keyboard focus traversal reaches all controls in order.
- [ ] Focus is visible, never trapped, and returns sensibly after changing view or opening the list.
- [ ] Maximum supported font size and 200% text scale do not clip or overlap labels.
- [ ] Minimum supported display width and 320 logical px layout remain usable.
- [ ] Landscape and portrait layouts both keep controls reachable without horizontal scrolling.
- [ ] Grayscale mode preserves selected, suggested, error, and focus distinctions.
- [ ] Color-correction modes (including red/green and blue/yellow adjustments) preserve the same distinctions.

## Picker behavior matrix

- [ ] Representative diagram route: tap a component, verify its name/selected state, then Use.
- [ ] Representative list route: search/filter, select a component, verify selected state, then Use.
- [ ] Narrow target: test the smallest visible component target and verify it is discoverable and activatable.
- [ ] Ambiguity: tap an overlapping/ambiguous region; candidates are announced and can be chosen deterministically.
- [ ] Suggestion: open with a detector suggestion; Suggested is announced and accepting/overriding it is clear.
- [ ] Validation error: attempt Use without a selection; the required error is visible and announced.
- [ ] View changes: switch front/rear/left/right/top and verify the active view and component list remain synchronized.
- [ ] Cancel: changes made in the picker are discarded when Cancel is used.
- [ ] Undo: Undo removes the most recent local selection and restores the prior state.
- [ ] System Back: Back follows the same discard/close contract as Cancel and never silently accepts.
- [ ] Use: Use returns exactly the canonical component selected by the user.
- [ ] Rotation/rebuild: selected component, active view, query, and pending ambiguity survive the supported configuration change.

## Parent workflow matrix

Verify the summary row opens the picker and the returned canonical selection is reflected in each entry point:

- [ ] Confirm finding
- [ ] Edit finding
- [ ] Add Manual finding
- [ ] Merge findings
- [ ] Split finding — first component field
- [ ] Split finding — second component field

For each entry point, verify required-field validation, Cancel/system Back behavior, and that only parent-form submission persists the change.

## Exit criteria

- [ ] No automated gate failures.
- [ ] No Accessibility Scanner findings that violate the product target; accepted findings are documented here.
- [ ] All device matrix checks pass or have a linked, triaged defect.
- [ ] Evidence (logs, screenshots, recordings, and scanner output) is attached to the release ticket.
- [ ] Any manual/device-blocked item is explicitly recorded with owner and follow-up ticket.

### Manual/device-blocked notes

| Check | Result / evidence | Defect or follow-up |
| --- | --- | --- |
|  |  |  |
|  |  |  |
|  |  |  |
