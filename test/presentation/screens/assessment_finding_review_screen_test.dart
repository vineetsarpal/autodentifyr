import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_finding_review_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentFindingReviewScreen', () {
    testWidgets('Appraiser sees model evidence before reviewing a Finding', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final firstCaptureImage = tester.widget<Image>(
        find.byKey(const Key('finding-observation-image-observation-1')),
      );
      expect(firstCaptureImage.image, isA<FileImage>());
      expect(
        (firstCaptureImage.image as FileImage).file.path,
        '/evidence/capture-1.jpg',
      );
      expect(find.text('Model observation: dent'), findsOneWidget);
      expect(find.text('80.0% confidence'), findsNWidgets(2));
      expect(find.text('Camera still • Capture capture-1'), findsOneWidget);
      expect(
        find.text('Vehicle Component: Appraiser confirmation required'),
        findsNWidgets(2),
      );
      expect(
        find.text('Damage Type: Appraiser confirmation required'),
        findsNWidgets(2),
      );
    });

    testWidgets('Appraiser confirms a Proposed Finding with required values', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('2 Proposed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-proposed-observation-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vehicle-component')),
        'left-front door',
      );
      await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Visible dent matches the retained Capture.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('left-front door • dent'), findsOneWidget);
    });

    testWidgets('Appraiser edits, dismisses, and manually adds Findings', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-proposed-observation-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vehicle-component')),
        'left-front fender',
      );
      await tester.enterText(find.byKey(const Key('damage-type')), 'crease');
      await tester.enterText(find.byKey(const Key('capture-ids')), 'capture-1');
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Corrected values.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      expect(find.text('left-front fender • crease'), findsOneWidget);

      final dismissButton = find.byKey(
        const Key('dismiss-proposed-observation-2'),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Reflection only.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      expect(find.text('Dismissed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-manual-finding')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vehicle-component')),
        'hood',
      );
      await tester.enterText(find.byKey(const Key('damage-type')), 'scratch');
      await tester.enterText(find.byKey(const Key('capture-ids')), 'capture-1');
      await tester.enterText(
        find.byKey(const Key('evidence-note')),
        'Scratch visible near the hood edge.',
      );
      await tester.enterText(find.byKey(const Key('reason')), 'Manual review.');
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('hood • scratch'), 300);
      expect(find.text('hood • scratch'), findsOneWidget);
    });

    testWidgets('Appraiser records uncertainty and an Undetermined outcome', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('uncertainty-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
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
      expect(find.text('Conflicting views'), findsOneWidget);
      expect(
        find.text('Capture an oblique view of the left-front door.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('undetermined-proposed-observation-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Available evidence does not support a conclusion.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('status-proposed-observation-1')),
            )
            .data,
        'Undetermined',
      );
    });

    testWidgets('Appraiser explicitly merges and splits Findings', (
      tester,
    ) async {
      final harness = await _Harness.create();
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('select-proposed-observation-1')));
      await tester.tap(find.byKey(const Key('select-proposed-observation-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('merge-selected')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vehicle-component')),
        'left-front door',
      );
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
      expect(find.text('left-front door • surface damage'), findsOneWidget);

      await tester.tap(find.byKey(const Key('split-generated-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('part-1-component')),
        'left-front door',
      );
      await tester.enterText(find.byKey(const Key('part-1-type')), 'dent');
      await tester.enterText(
        find.byKey(const Key('part-1-observations')),
        'observation-1',
      );
      await tester.enterText(
        find.byKey(const Key('part-1-captures')),
        'capture-1',
      );
      await tester.enterText(
        find.byKey(const Key('part-2-component')),
        'left-front door',
      );
      await tester.enterText(find.byKey(const Key('part-2-type')), 'scratch');
      await tester.enterText(
        find.byKey(const Key('part-2-observations')),
        'observation-2',
      );
      await tester.enterText(
        find.byKey(const Key('part-2-captures')),
        'capture-2',
      );
      await tester.enterText(
        find.byKey(const Key('reason')),
        'Two separately reviewable areas.',
      );
      await tester.tap(find.byKey(const Key('submit-action')));
      await tester.pumpAndSettle();

      expect(find.text('left-front door • dent'), findsOneWidget);
      expect(find.text('left-front door • scratch'), findsOneWidget);
    });

    testWidgets(
      'Appraiser must explain overriding an additional-view request',
      (tester) async {
        final harness = await _Harness.create();
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('uncertainty-proposed-observation-1')),
        );
        await tester.pumpAndSettle();
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

        await tester.tap(
          find.byKey(const Key('confirm-proposed-observation-1')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('vehicle-component')),
          'left-front door',
        );
        await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
        await tester.enterText(find.byKey(const Key('reason')), 'Confirmed.');
        await tester.tap(find.byKey(const Key('submit-action')));
        await tester.pumpAndSettle();
        expect(find.textContaining('override reason'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('confirm-proposed-observation-1')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('vehicle-component')),
          'left-front door',
        );
        await tester.enterText(find.byKey(const Key('damage-type')), 'dent');
        await tester.enterText(find.byKey(const Key('reason')), 'Confirmed.');
        await tester.enterText(
          find.byKey(const Key('override-reason')),
          'Another retained Capture shows the edge.',
        );
        await tester.tap(find.byKey(const Key('submit-action')));
        await tester.pumpAndSettle();
        expect(find.text('Confirmed'), findsOneWidget);
      },
    );
  });
}

class _Harness {
  _Harness(this.repository, this.controller);

  final InMemoryAssessmentRepository repository;
  final AssessmentFindingReviewController controller;

  Widget get widget =>
      MaterialApp(home: AssessmentFindingReviewScreen(controller: controller));

  static Future<_Harness> create() async {
    final repository = InMemoryAssessmentRepository();
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
    for (final entry in const [
      ('observation-1', 'capture-1', 'dent'),
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
