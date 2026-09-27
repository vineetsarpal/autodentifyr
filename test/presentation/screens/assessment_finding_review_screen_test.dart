import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_finding_review_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fail_next_assessment_save_repository.dart';

void main() {
  group('AssessmentFindingReviewScreen', () {
    testWidgets('Review Findings starts as a focused review queue', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Finding 1 of 2'), findsOneWidget);
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('finding-observation-image-observation-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('finding-observation-image-observation-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('not-damage-proposed-observation-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
        findsOneWidget,
      );
      expect(find.text('Vehicle condition'), findsNothing);
      expect(find.text('Reviewed (0)'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const Key('merge-selected')), findsNothing);
    });

    testWidgets('Confirm and next accepts an exact suggestion in one tap', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final persisted = (await harness.repository.findById('assessment-1'))!;
      final confirmed = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(confirmed.reviewState, FindingReviewState.confirmed);
      expect(confirmed.vehicleComponentId, VehicleComponentId.frontBumper);
      expect(confirmed.damageType, 'front-bumper-dent');
      expect(
        persisted.corrections.single.reason,
        'Appraiser confirmed the displayed component and damage type.',
      );
      expect(find.text('Finding 1 of 1'), findsOneWidget);
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-1')),
        findsNothing,
      );
    });

    testWidgets('Not damage dismisses with a compact reason choice', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('not-damage-proposed-observation-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dismiss Finding'), findsNothing);
      final reflection = find.byKey(const Key('dismiss-reason-reflection'));
      expect(reflection, findsOneWidget);
      await tester.tap(reflection);
      await tester.pumpAndSettle();

      final persisted = (await harness.repository.findById('assessment-1'))!;
      final dismissed = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(dismissed.reviewState, FindingReviewState.dismissed);
      expect(persisted.corrections.single.reason, 'Reflection');
      expect(find.text('Finding 1 of 1'), findsOneWidget);
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-1')),
        findsNothing,
      );
    });

    testWidgets('Assessment and finding actions use separate menus', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      for (final legacyAction in [
        'Confirm',
        'Edit',
        'Dismiss',
        'Uncertainty',
        'Undetermined',
        'Split',
      ]) {
        expect(find.text(legacyAction), findsNothing);
      }

      await tester.tap(find.byKey(const Key('assessment-actions-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Add finding'), findsOneWidget);
      expect(find.text('Merge findings'), findsOneWidget);
      expect(find.text('View vehicle map'), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('finding-more-actions-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Need more evidence'), findsOneWidget);
      expect(find.text('Cannot determine'), findsOneWidget);
      expect(find.text('Split finding'), findsOneWidget);
    });

    testWidgets(
      'Merge findings is hidden when fewer than two eligible findings remain',
      (tester) async {
        final harness = await _Harness.create();
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('not-damage-proposed-observation-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dismiss-reason-reflection')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('assessment-actions-menu')));
        await tester.pumpAndSettle();

        expect(find.text('Add finding'), findsOneWidget);
        expect(find.text('Merge findings'), findsNothing);
        expect(find.text('View vehicle map'), findsOneWidget);
      },
    );

    testWidgets('Reviewed findings stay collapsed until requested', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();

      final reviewedSection = find.byKey(const Key('reviewed-findings'));
      expect(reviewedSection, findsOneWidget);
      expect(find.text('Reviewed (1)'), findsOneWidget);
      expect(find.text('Front bumper • front-bumper-dent'), findsNothing);
      expect(find.text('Confirmed'), findsNothing);

      await tester.tap(reviewedSection);
      await tester.pumpAndSettle();

      expect(find.text('Front bumper • front-bumper-dent'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('Dismissed finding can be reopened and confirmed', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('not-damage-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dismiss-reason-reflection')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reviewed-findings')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('reviewed-finding-proposed-observation-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review finding'), findsOneWidget);
      expect(
        find.byKey(const Key('dialog-evidence-proposed-observation-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('component-selector-Vehicle Component')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('damage-type')), findsOneWidget);

      await _selectComponent(tester, 'Vehicle Component', 'left-front door');
      await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Confirmed after reviewing the dismissed finding.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();

      final persisted = (await harness.repository.findById('assessment-1'))!;
      final finding = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(finding.reviewState, FindingReviewState.confirmed);
      expect(finding.vehicleComponentId, VehicleComponentId.leftFrontDoor);
      expect(finding.damageType, 'dent');
      expect(persisted.corrections.map((correction) => correction.kind), [
        AssessmentCorrectionKind.dismiss,
        AssessmentCorrectionKind.confirm,
      ]);
      expect(persisted.corrections.map((correction) => correction.reason), [
        'Reflection',
        'Confirmed after reviewing the dismissed finding.',
      ]);
    });

    testWidgets('Continue unlocks after every finding is reviewed', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      var continueCalls = 0;
      await tester.pumpWidget(
        harness.widgetWithContinue(() => continueCalls++),
      );
      await tester.pumpAndSettle();

      final continueButton = find.byKey(const Key('continue-assessment'));
      expect(find.text('Review 2 remaining'), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('not-damage-proposed-observation-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dismiss-reason-reflection')));
      await tester.pumpAndSettle();

      expect(find.text('Continue to severity'), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
      await tester.tap(continueButton);
      await tester.pump();
      expect(continueCalls, 1);
    });

    testWidgets('Focused suggestion chips open the finding editor', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final componentChip = find.byKey(const Key('focused-component'));
      final damageTypeChip = find.byKey(const Key('focused-damage-type'));
      expect(componentChip, findsOneWidget);
      expect(
        find.descendant(of: componentChip, matching: find.text('Front bumper')),
        findsOneWidget,
      );
      expect(damageTypeChip, findsOneWidget);
      expect(
        find.descendant(
          of: damageTypeChip,
          matching: find.text('front-bumper-dent'),
        ),
        findsOneWidget,
      );

      await tester.tap(componentChip);
      await tester.pumpAndSettle();

      expect(find.text('Review finding'), findsOneWidget);
      expect(
        find.byKey(const Key('component-selector-Vehicle Component')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('damage-type')), findsOneWidget);
    });

    testWidgets('Merge findings enters a two-selection mode', (tester) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assessment-actions-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merge findings'));
      await tester.pumpAndSettle();

      expect(find.text('Select findings'), findsOneWidget);
      expect(find.byKey(const Key('cancel-merge-mode')), findsOneWidget);
      final firstSelection = find.byKey(
        const Key('select-proposed-observation-1'),
      );
      final secondSelection = find.byKey(
        const Key('select-proposed-observation-2'),
      );
      expect(firstSelection, findsOneWidget);
      expect(secondSelection, findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      final mergeButton = find.byKey(const Key('merge-selected'));
      expect(mergeButton, findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(mergeButton).onPressed, isNull);
      await tester.tap(firstSelection);
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(mergeButton).onPressed, isNull);
      await tester.tap(secondSelection);
      await tester.pump();
      expect(
        tester.widget<ButtonStyleButton>(mergeButton).onPressed,
        isNotNull,
      );
    });

    testWidgets('Quick confirm stays retryable after a save failure', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final confirm = find.byKey(
        const Key('confirm-and-next-proposed-observation-1'),
      );
      harness.repository.failNextSave = true;
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('focused-finding-proposed-observation-1')),
        findsOneWidget,
      );
      expect(
        find.text('Device storage is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(confirm, findsOneWidget);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Finding 1 of 1'), findsOneWidget);
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('focused-finding-proposed-observation-1')),
        findsNothing,
      );
    });

    testWidgets(
      'manual finding chooses a component full-screen before showing fields',
      (tester) async {
        final harness = await _Harness.create();
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        await _openAssessmentAction(tester, 'Add finding');
        expect(find.text('Select vehicle component'), findsOneWidget);
        await _chooseTopMapComponent(tester, 'Hood');
        await tester.tap(find.text('Use Hood'));
        await tester.pumpAndSettle();

        final hoodId = VehicleComponentCatalog.all
            .singleWhere((component) => component.label == 'Hood')
            .id;
        final persisted = await harness.repository.findById('assessment-1');
        expect(
          persisted!.findings.where(
            (finding) => finding.vehicleComponentId == hoodId,
          ),
          isEmpty,
        );

        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Add manual Finding'),
          ),
          findsOneWidget,
        );
        final componentSelector = find.byKey(
          const Key('component-selector-Vehicle Component'),
        );
        expect(
          find.descendant(of: componentSelector, matching: find.text('Hood')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Change component preserves unfinished manual form values', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _openAssessmentAction(tester, 'Add finding');
      await _chooseTopMapComponent(tester, 'Hood');
      await tester.tap(find.text('Use Hood'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('damage-type')), 'scratch');
      await tester.enterText(
        find.byKey(const Key('evidence-note')),
        'Visible near the edge.',
      );
      await tester.enterText(find.byKey(const Key('reason')), 'Manual review.');

      await _selectComponent(tester, 'Vehicle Component', 'roof');

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('damage-type')))
            .controller!
            .text,
        'scratch',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('evidence-note')))
            .controller!
            .text,
        'Visible near the edge.',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('reason')))
            .controller!
            .text,
        'Manual review.',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('component-selector-Vehicle Component')),
          matching: find.text('Roof'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('map evidence action opens the existing observation viewer', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();

      await _openAssessmentAction(tester, 'View vehicle map');
      await _chooseTopMapComponent(tester, 'Front bumper');
      final viewEvidence = find.byTooltip('View evidence');
      await _tapVisible(tester, viewEvidence);
      await tester.pumpAndSettle();

      expect(find.text('Model evidence'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const Key('finding-observation-bounds-observation-1')),
        findsOneWidget,
      );
    });

    testWidgets('Appraiser sees model evidence before reviewing a Finding', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final modelObservation = find.text('Suggested dent • 80.0% confidence');
      expect(modelObservation, findsOneWidget);
      final firstCaptureImage = tester.widget<Image>(
        find.byKey(const Key('finding-observation-image-observation-1')),
      );
      expect(firstCaptureImage.image, isA<FileImage>());
      expect(
        (firstCaptureImage.image as FileImage).file.path,
        '/evidence/capture-1.jpg',
      );
      expect(
        find.byKey(const Key('finding-thumbnail-bounds-observation-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('finding-thumbnail-bounds-observation-2')),
        findsNothing,
      );
      expect(find.text('Camera still'), findsOneWidget);
      expect(find.text('Camera still • photo capture-1'), findsNothing);
    });

    testWidgets('Appraiser enlarges a Capture with its model bounds', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(const Key('open-finding-observation-observation-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Model evidence'), findsOneWidget);
      expect(find.text('dent • 80.0% confidence'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const Key('finding-observation-bounds-observation-1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('close-model-evidence')));
      await tester.pumpAndSettle();
      expect(find.text('Model evidence'), findsNothing);
    });

    testWidgets('Appraiser confirms a Proposed Finding with required values', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Finding 1 of 2'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dialog-evidence-proposed-observation-1')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('dialog-evidence-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byKey(const Key('close-model-evidence')));
      await tester.pumpAndSettle();
      await _selectComponent(tester, 'Vehicle Component', 'left-front door');
      await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Visible dent matches the retained Capture.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reviewed-findings')));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Left front door • dent'), findsOneWidget);
      final persisted = (await harness.repository.findById('assessment-1'))!;
      final confirmed = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(confirmed.reviewState, FindingReviewState.confirmed);
      expect(confirmed.vehicleComponentId, VehicleComponentId.leftFrontDoor);
      expect(confirmed.damageType, 'dent');
    });

    testWidgets('Confirm derives an exact detector suggestion from evidence', (
      tester,
    ) async {
      final harness = await _Harness.create(
        firstObservationClass: 'front-bumper-dent',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('focused-component')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('component-selector-Vehicle Component')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No component selected'), findsOneWidget);
      expect(find.text('Suggested: Front bumper'), findsOneWidget);
      expect(find.text('80.0% confidence'), findsOneWidget);
    });

    testWidgets('Confirm presents detector candidates', (tester) async {
      final candidateHarness = await _Harness.create(
        firstObservationClass: 'headlight-damage',
      );
      await tester.pumpWidget(candidateHarness.widget);
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('component-selector-Vehicle Component')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Suggested components'), findsOneWidget);
      expect(
        find.byKey(const Key('candidate-component-left_headlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('candidate-component-right_headlight')),
        findsOneWidget,
      );
    });

    testWidgets('Confirm starts empty for unknown detector evidence', (
      tester,
    ) async {
      final unknownHarness = await _Harness.create();
      await tester.pumpWidget(unknownHarness.widget);
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('component-selector-Vehicle Component')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No component selected'), findsOneWidget);
      expect(find.text('Suggested: Dent'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('Appraiser corrects, dismisses, and manually adds Findings', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(const Key('confirm-and-next-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await _selectComponent(tester, 'Vehicle Component', 'left-front fender');
      await tester.enterText(find.byKey(const Key('damage-type')), 'crease');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Corrected values.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      var persisted = (await harness.repository.findById('assessment-1'))!;
      final corrected = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(corrected.reviewState, FindingReviewState.confirmed);
      expect(corrected.vehicleComponentId, VehicleComponentId.leftFrontFender);
      expect(corrected.damageType, 'crease');

      await tester.tap(
        find.byKey(const Key('not-damage-proposed-observation-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dismiss-reason-other')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Reflection only.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      persisted = (await harness.repository.findById('assessment-1'))!;
      final dismissed = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-2',
      );
      expect(dismissed.reviewState, FindingReviewState.dismissed);
      expect(persisted.corrections.last.reason, 'Reflection only.');

      await _openAssessmentAction(tester, 'Add finding');
      await _chooseTopMapComponent(tester, 'Hood');
      await tester.tap(find.text('Use Hood'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('damage-type')), 'scratch');
      await _selectCapture(tester, 'capture-1');
      await tester.enterText(
        find.byKey(const Key('evidence-note')),
        'Scratch visible near the hood edge.',
      );
      await tester.enterText(find.byKey(const Key('reason')), 'Manual review.');
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      persisted = (await harness.repository.findById('assessment-1'))!;
      final manual = persisted.findings.singleWhere(
        (finding) => finding.manualEvidenceNote != null,
      );
      expect(manual.reviewState, FindingReviewState.confirmed);
      expect(manual.vehicleComponentId, VehicleComponentId.hood);
      expect(manual.damageType, 'scratch');
      expect(manual.manualEvidenceNote, 'Scratch visible near the hood edge.');
    });

    testWidgets('Appraiser records uncertainty and an Undetermined outcome', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await _openFindingAction(
        tester,
        'proposed-observation-1',
        'Need more evidence',
      );
      await tester.tap(find.byKey(const Key('conflicting-views')));
      await tester.enterText(
        find.byKey(const Key('additional-views')),
        'Capture an oblique view of the left-front door.',
      );
      await tester.enterText(
        find.byKey(const Key('reason')),
        'The retained views conflict.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      var persisted = (await harness.repository.findById('assessment-1'))!;
      var finding = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(finding.hasConflictingViews, isTrue);
      expect(finding.additionalViewRequests, [
        'Capture an oblique view of the left-front door.',
      ]);

      await _openFindingAction(
        tester,
        'proposed-observation-1',
        'Cannot determine',
      );
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Available evidence does not support a conclusion.',
      );
      await tester.enterText(
        find.byKey(const Key('override-reason')),
        'No further capture is available.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      persisted = (await harness.repository.findById('assessment-1'))!;
      finding = persisted.findings.singleWhere(
        (finding) => finding.id == 'proposed-observation-1',
      );
      expect(finding.reviewOutcome, FindingReviewOutcome.undetermined);
      expect(
        finding.additionalViewOverrideReason,
        'No further capture is available.',
      );
    });

    testWidgets('Appraiser explicitly merges and splits Findings', (
      tester,
    ) async {
      final mergeHarness = await _Harness.create();
      await tester.pumpWidget(mergeHarness.widget);
      await tester.pumpAndSettle();

      await _openAssessmentAction(tester, 'Merge findings');
      await _tapVisible(
        tester,
        find.byKey(const Key('select-proposed-observation-1')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('select-proposed-observation-2')),
      );
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('merge-selected')));
      await tester.pumpAndSettle();
      await _selectComponent(tester, 'Vehicle Component', 'left-front door');
      await tester.enterText(
        find.byKey(const Key('damage-type')),
        'surface damage',
      );
      await tester.enterText(
        find.byKey(const Key('reason')),
        'One damaged area.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      final mergedAssessment = (await mergeHarness.repository.findById(
        'assessment-1',
      ))!;
      expect(mergedAssessment.findings, hasLength(1));
      expect(
        mergedAssessment.findings.single.vehicleComponentId,
        VehicleComponentId.leftFrontDoor,
      );
      expect(mergedAssessment.findings.single.damageType, 'surface damage');
      expect(mergedAssessment.findings.single.observationIds, [
        'observation-1',
        'observation-2',
      ]);

      final splitHarness = await _Harness.create(combinedFinding: true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(splitHarness.widget);
      await tester.pumpAndSettle();
      await _openFindingAction(tester, 'combined-finding', 'Split finding');
      await _selectComponent(
        tester,
        'First Vehicle Component',
        'left-front door',
      );
      await tester.enterText(find.byKey(const Key('part-1-type')), 'dent');
      await _selectObservation(
        tester,
        'observation-1',
        within: 'part-1-observations',
      );
      await _selectCapture(tester, 'capture-1', within: 'part-1-captures');
      await _selectComponent(
        tester,
        'Second Vehicle Component',
        'left-front door',
      );
      await tester.enterText(find.byKey(const Key('part-2-type')), 'scratch');
      await _selectObservation(
        tester,
        'observation-2',
        within: 'part-2-observations',
      );
      await _selectCapture(tester, 'capture-2', within: 'part-2-captures');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Two separately reviewable areas.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();

      final splitAssessment = (await splitHarness.repository.findById(
        'assessment-1',
      ))!;
      expect(splitAssessment.findings, hasLength(2));
      expect(splitAssessment.findings.map((finding) => finding.damageType), [
        'dent',
        'scratch',
      ]);
      expect(
        splitAssessment.findings.map((finding) => finding.observationIds),
        [
          ['observation-1'],
          ['observation-2'],
        ],
      );
    });

    testWidgets(
      'Appraiser must explain overriding an additional-view request',
      (tester) async {
        final harness = await _Harness.create();
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();
        await _openFindingAction(
          tester,
          'proposed-observation-1',
          'Need more evidence',
        );
        await tester.enterText(
          find.byKey(const Key('additional-views')),
          'Capture the lower door edge.',
        );
        await tester.enterText(
          find.byKey(const Key('reason')),
          'Edge is occluded.',
        );
        await tester.tap(find.byKey(const Key('submit-action')));
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const Key('confirm-and-next-proposed-observation-1')),
        );
        await tester.pumpAndSettle();
        await _selectComponent(tester, 'Vehicle Component', 'left-front door');
        await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
        await tester.enterText(find.byKey(const Key('reason')), 'Confirmed.');
        await tester.tap(find.byKey(const Key('submit-action')));
        await tester.pumpAndSettle();
        expect(
          find.text('Additional-view override reason is required.'),
          findsOneWidget,
        );
        expect(find.text('Review finding'), findsOneWidget);
        expect(find.text('Confirmed.'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('override-reason')),
          'Another retained Capture shows the edge.',
        );
        await tester.tap(find.byKey(const Key('submit-action')));
        await tester.pumpAndSettle();
        final persisted = (await harness.repository.findById('assessment-1'))!;
        final confirmed = persisted.findings.singleWhere(
          (finding) => finding.id == 'proposed-observation-1',
        );
        expect(confirmed.reviewState, FindingReviewState.confirmed);
        expect(
          confirmed.additionalViewOverrideReason,
          'Another retained Capture shows the edge.',
        );
      },
    );

    testWidgets('manual finding save failure retains input for retry', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await _openAssessmentAction(tester, 'Add finding');
      await _chooseTopMapComponent(tester, 'Hood');
      await tester.tap(find.text('Use Hood'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('damage-type')), 'scratch');
      await _selectCapture(tester, 'capture-1');
      await tester.enterText(
        find.byKey(const Key('evidence-note')),
        'Scratch visible near the edge.',
      );
      await tester.enterText(find.byKey(const Key('reason')), 'Manual review.');
      harness.repository.failNextSave = true;
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      expect(
        find.text('Device storage is temporarily unavailable.'),
        findsWidgets,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Scratch visible near the edge.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final persisted = (await harness.repository.findById('assessment-1'))!;
      final manual = persisted.findings.singleWhere(
        (finding) => finding.manualEvidenceNote != null,
      );
      expect(manual.vehicleComponentId, VehicleComponentId.hood);
      expect(manual.damageType, 'scratch');
      expect(manual.manualEvidenceNote, 'Scratch visible near the edge.');
    });
  });
}

Future<void> _openAssessmentAction(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(const Key('assessment-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _openFindingAction(
  WidgetTester tester,
  String findingId,
  String action,
) async {
  await tester.tap(find.byKey(Key('finding-more-actions-$findingId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _selectComponent(
  WidgetTester tester,
  String label,
  String component,
) async {
  final selector = find.byKey(Key('component-selector-$label'));
  final dialogScrollable = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    selector,
    300,
    scrollable: dialogScrollable.last,
  );
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final id = VehicleComponentCatalog.all
      .singleWhere(
        (item) => item.label.toLowerCase() == component.replaceAll('-', ' '),
      )
      .id;
  final componentRecord = VehicleComponentCatalog.byId(id);
  await tester.tap(find.text('Browse components'));
  await tester.pumpAndSettle();
  final search = find.byKey(const Key('top-map-component-search'));
  await tester.enterText(search, componentRecord.label);
  await tester.pump();
  final componentChoice = find.byKey(Key('top-map-component-${id.wireValue}'));
  await tester.tap(componentChoice);
  await tester.pumpAndSettle();
  final useAnyway = find.text('Use component anyway');
  if (useAnyway.evaluate().isNotEmpty) {
    await _tapVisible(tester, useAnyway);
  } else {
    await _tapVisible(tester, find.text('Use ${componentRecord.label}'));
  }
}

Future<void> _chooseTopMapComponent(
  WidgetTester tester,
  String componentLabel,
) async {
  await tester.tap(find.text('Browse components'));
  await tester.pumpAndSettle();
  final search = find.byKey(const Key('top-map-component-search'));
  await tester.enterText(search, componentLabel);
  await tester.pump();
  final id = VehicleComponentCatalog.all
      .singleWhere((component) => component.label == componentLabel)
      .id;
  await tester.tap(find.byKey(Key('top-map-component-${id.wireValue}')));
  await tester.pumpAndSettle();
}

Future<void> _selectCapture(
  WidgetTester tester,
  String captureId, {
  String? within,
}) async {
  final choice = within == null
      ? find.byKey(Key('evidence-choice-$captureId'))
      : find.descendant(
          of: find.byKey(Key(within)),
          matching: find.byKey(Key('evidence-choice-$captureId')),
        );
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

Future<void> _selectObservation(
  WidgetTester tester,
  String observationId, {
  String? within,
}) async {
  final choice = within == null
      ? find.byKey(Key('observation-choice-$observationId'))
      : find.descendant(
          of: find.byKey(Key(within)),
          matching: find.byKey(Key('observation-choice-$observationId')),
        );
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.repository, this.controller);

  final FailNextAssessmentSaveRepository repository;
  final AssessmentFindingReviewController controller;

  Widget get widget =>
      MaterialApp(home: AssessmentFindingReviewScreen(controller: controller));

  Widget widgetWithContinue(VoidCallback onContinue) => MaterialApp(
    home: AssessmentFindingReviewScreen(
      controller: controller,
      onContinue: onContinue,
    ),
  );

  static Future<_Harness> create({
    String firstObservationClass = 'dent',
    bool combinedFinding = false,
  }) async {
    final repository = FailNextAssessmentSaveRepository(
      InMemoryAssessmentRepository(),
    );
    var assessment = IntakeAssessment.create(
      id: 'assessment-1',
      vehicle: const Vehicle(id: 'vehicle-1'),
      appraiserProfile: const AppraiserProfile(
        id: 'appraiser-1',
        displayName: 'Alex Appraiser',
      ),
      createdAt: DateTime.utc(2026, 9, 6, 18),
    );
    for (final captureId in ['capture-1', 'capture-2']) {
      assessment = assessment.acceptCapture(
        Capture(
          id: captureId,
          source: CaptureSource.camera,
          localPath: '/evidence/$captureId.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 6, 18, 1),
        ),
      );
    }
    for (final entry in [
      ('observation-1', 'capture-1', firstObservationClass),
      ('observation-2', 'capture-2', 'scratch'),
    ]) {
      assessment = assessment.recordObservation(
        DamageObservation(
          id: entry.$1,
          captureId: entry.$2,
          rawClass: entry.$3,
          confidence: 0.8,
          bounds: const ObservationBounds(
            left: 0.1,
            top: 0.2,
            width: 0.3,
            height: 0.4,
          ),
          modelIdentifier: 'test-model',
          runtimeIdentifier: 'test-runtime',
        ),
      );
    }
    if (combinedFinding) {
      assessment = assessment.addFinding(
        DamageFinding.proposed(
          id: 'combined-finding',
          observationIds: const ['observation-1', 'observation-2'],
          supportingCaptureIds: const ['capture-1', 'capture-2'],
          suggestedDamageType: 'surface damage',
        ),
      );
    }
    await repository.save(assessment);
    var sequence = 0;
    return _Harness(
      repository,
      AssessmentFindingReviewController(
        assessmentId: 'assessment-1',
        repository: repository,
        idGenerator: () => 'generated-${sequence++}',
        now: () => DateTime.utc(2026, 9, 7, 1, 2),
      ),
    );
  }
}
