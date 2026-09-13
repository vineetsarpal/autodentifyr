import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_severity_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentSeverityScreen', () {
    testWidgets(
      'unavailable automation leaves all four Appraiser outcomes available',
      (tester) async {
        final harness = await _Harness.create(
          const UnavailableSeveritySuggestionSource(),
        );
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        expect(find.text('Automation unavailable'), findsOneWidget);
        expect(find.text('Minor — Localized visible extent'), findsOneWidget);
        expect(
          find.text('Moderate — Intermediate visible extent'),
          findsOneWidget,
        );
        expect(find.text('Severe — Widespread visible extent'), findsOneWidget);
        expect(
          find.text('Undetermined — Evidence insufficient'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('review-severity-finding-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('severity-level')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Minor').last);
        await tester.enterText(
          find.byKey(const Key('severity-reason')),
          'Visible damage is localized on the component.',
        );
        await tester.tap(find.byKey(const Key('submit-severity-review')));
        await tester.pumpAndSettle();

        expect(
          find.text('Appraiser conclusion: Minor — Localized'),
          findsOneWidget,
        );
        expect(find.text('Evidence Captures: capture-1'), findsOneWidget);
      },
    );

    testWidgets(
      'synthetic suggestion override exposes report-ready provenance',
      (tester) async {
        final harness = await _Harness.create(
          const _SyntheticSeveritySuggestionSource(),
        );
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        expect(
          find.text('Synthetic workflow-only suggestion: Moderate'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('review-severity-finding-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('severity-level')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Severe').last);
        await tester.enterText(
          find.byKey(const Key('severity-reason')),
          'Visible damage is widespread across the component.',
        );
        await tester.enterText(
          find.byKey(const Key('severity-uncertainty')),
          'The lower edge remains partly obscured.',
        );
        await tester.tap(find.byKey(const Key('submit-severity-review')));
        await tester.pumpAndSettle();

        expect(
          find.text('Appraiser conclusion: Severe — Widespread'),
          findsOneWidget,
        );
        expect(
          find.text('Original suggestion: Moderate (synthetic workflow only)'),
          findsOneWidget,
        );
        expect(
          find.text('Suggestion source: synthetic-workflow-only-v1'),
          findsOneWidget,
        );
        expect(find.text('Suggestion evidence: capture-1'), findsOneWidget);
        expect(find.text('Reviewed by appraiser-1'), findsOneWidget);
        expect(
          find.text('Reviewed at 2026-09-07T17:00:00.000Z'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Reason: Visible damage is widespread across the component.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'conflicting captures support an explicit Undetermined outcome and view request',
      (tester) async {
        final harness = await _Harness.create(
          const UnavailableSeveritySuggestionSource(),
          conflictingViews: true,
        );
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        expect(find.text('Conflicting captures'), findsOneWidget);
        await tester.tap(find.byKey(const Key('review-severity-finding-1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('severity-reason')),
          'Available evidence does not support a severity conclusion.',
        );
        await tester.enterText(
          find.byKey(const Key('severity-uncertainty')),
          'Reflections conflict near the lower component edge.',
        );
        await tester.enterText(
          find.byKey(const Key('severity-additional-view')),
          'Capture an oblique view of the left-front door lower edge.',
        );
        await tester.tap(find.byKey(const Key('submit-severity-review')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Appraiser conclusion: Undetermined — Evidence insufficient',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Additional view requested: Capture an oblique view of the left-front door lower edge.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

class _SyntheticSeveritySuggestionSource implements SeveritySuggestionSource {
  const _SyntheticSeveritySuggestionSource();

  @override
  Future<SeveritySuggestionBatch> suggest(
    List<DamageFinding> confirmedFindings,
    List<Capture> captures,
  ) async => const SeveritySuggestionBatch.supported(
    sourceVersion: 'synthetic-workflow-only-v1',
    isSynthetic: true,
    suggestions: [
      SeveritySuggestion(
        findingId: 'finding-1',
        level: SeverityLevel.moderate,
        evidenceCaptureIds: ['capture-1'],
      ),
    ],
  );
}

class _Harness {
  const _Harness(this.controller);

  final AssessmentSeverityController controller;

  Widget get widget =>
      MaterialApp(home: AssessmentSeverityScreen(controller: controller));

  static Future<_Harness> create(
    SeveritySuggestionSource source, {
    bool conflictingViews = false,
  }) async {
    final repository = InMemoryAssessmentRepository();
    await repository.save(_assessment(conflictingViews: conflictingViews));
    return _Harness(
      AssessmentSeverityController(
        assessmentId: 'assessment-1',
        repository: repository,
        source: source,
        now: () => DateTime.utc(2026, 9, 7, 17),
      ),
    );
  }
}

IntakeAssessment _assessment({bool conflictingViews = false}) {
  var proposed = DamageFinding.proposed(
    id: 'finding-1',
    observationIds: const ['observation-1'],
    supportingCaptureIds: const ['capture-1'],
    suggestedVehicleComponent: 'left-front door',
    suggestedDamageType: 'dent',
  );
  if (conflictingViews) {
    proposed = proposed.withUncertainty(
      hasConflictingViews: true,
      additionalViewRequests: const [],
    );
  }
  final confirmed = proposed.reviewed(
    state: FindingReviewState.confirmed,
    vehicleComponent: 'left-front door',
    damageType: 'dent',
  );
  return IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 7, 15),
      )
      .acceptCapture(
        Capture(
          id: 'capture-1',
          source: CaptureSource.camera,
          localPath: '/evidence/capture-1.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 7, 15, 1),
        ),
      )
      .recordObservation(
        const DamageObservation(
          id: 'observation-1',
          captureId: 'capture-1',
          rawClass: 'dent',
          confidence: 0.8,
          bounds: ObservationBounds(
            left: 0.1,
            top: 0.2,
            width: 0.3,
            height: 0.4,
          ),
          modelIdentifier: 'test-model',
          runtimeIdentifier: 'test-runtime',
        ),
      )
      .addFinding(confirmed);
}
